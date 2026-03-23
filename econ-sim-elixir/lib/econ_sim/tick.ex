defmodule EconSim.Tick do
  @moduledoc """
  Main simulation tick — pure reducer mapping WorldState -> WorldState.
  Direct port of src/engine/tick.ts.
  """

  alias EconSim.Types.{Agent, Position, MarketState, WorldState}
  alias EconSim.{Globals, Math, Init, Market}

  @doc """
  Advances the simulation by one tick. Pure function.
  """
  @spec tick(WorldState.t(), keyword()) :: WorldState.t()
  def tick(%WorldState{} = prev, opts \\ []) do
    markets_enabled = Keyword.get(opts, :markets_enabled, false)

    # 1. Environment update — food grows
    next_grid = update_environment(prev.grid)

    # 2. Resolve agent actions tile by tile
    {next_grid, resolved_living} = resolve_all_agents(prev.agents, next_grid)

    # 3. Re-merge dead agents
    dead_agents = Enum.filter(prev.agents, & &1.is_dead)
    all_resolved = resolved_living ++ dead_agents

    # 4. Per-tick hunger/consumption and death
    {next_agents, next_grid} = apply_hunger_and_death(all_resolved, next_grid, prev.tick)

    # 5. Reproduction
    {next_agents, _next_grid} = apply_reproduction(next_agents, next_grid, prev.tick)

    # 6. Market resolution
    {final_agents, market_state} =
      if markets_enabled do
        %{bids: bids, asks: asks} = Market.generate_orders(next_agents)
        %{updated_agents: ua, market_state: ms} = Market.resolve_market(bids, asks, next_agents, prev.tick + 1)
        {ua, ms}
      else
        {next_agents, %MarketState{}}
      end

    %WorldState{
      tick: prev.tick + 1,
      grid: next_grid,
      agents: final_agents,
      market: market_state
    }
  end

  @doc """
  Grows food on food squares.
  """
  def update_environment(grid) do
    Enum.map(grid, fn row ->
      Enum.map(row, fn sq ->
        if sq.type == :food do
          %{sq | food_resources: min(Globals.max_food_per_block(), sq.food_resources + Globals.food_growth_rate())}
        else
          sq
        end
      end)
    end)
  end

  # Resolve all living agents grouped by tile position
  defp resolve_all_agents(agents, grid) do
    living = Enum.filter(agents, &(!&1.is_dead))

    groups =
      Enum.group_by(living, fn a -> {a.pos.x, a.pos.y} end)

    {final_grid, all_resolved} =
      Enum.reduce(groups, {grid, []}, fn {{x, y}, occupants}, {grid_acc, agents_acc} ->
        sq = grid_acc |> Enum.at(y) |> Enum.at(x)
        n = length(occupants)

        # Available resources
        total_avail_f = sq.food_resources

        total_avail_g =
          if sq.type == :gold,
            do: min(n * 1.0, sq.gold_resources),
            else: sq.gold_resources

        expected_deltas = %{df: total_avail_f / n, dg: total_avail_g / n}

        # Poll each agent: exploit or explore?
        {exploiters, explorers} =
          Enum.split_with(occupants, fn a ->
            resolve_agent_decision(a, expected_deltas) == :exploit
          end)

        m = length(exploiters)

        # Calculate actual extraction
        {actual_df, actual_dg, grid_acc} =
          if m > 0 do
            total_extracted_f = min(total_avail_f, m * expected_deltas.df)
            total_extracted_g = min(total_avail_g, m * expected_deltas.dg)

            updated_sq = %{
              sq
              | food_resources: max(0.0, sq.food_resources - total_extracted_f),
                gold_resources: max(0.0, sq.gold_resources - total_extracted_g)
            }

            grid_acc = update_grid_at(grid_acc, x, y, updated_sq)
            {total_extracted_f / m, total_extracted_g / m, grid_acc}
          else
            {0.0, 0.0, grid_acc}
          end

        # Process explorers — move to random adjacent tile
        grid_height = length(grid_acc)
        grid_width = length(Enum.at(grid_acc, 0))

        moved_explorers =
          Enum.map(explorers, fn agent ->
            adjs = get_adjacent_positions(agent.pos, grid_width, grid_height)
            new_pos = Enum.random(adjs)
            %{agent | pos: new_pos}
          end)

        # Process exploiters — gain resources and eat
        updated_exploiters =
          Enum.map(exploiters, fn agent ->
            new_food = agent.food_inventory + actual_df
            new_hunger = agent.curr_hunger

            # Satisfy hunger loop
            {new_hunger, new_food} =
              if actual_df > 0 do
                satisfy_hunger(new_hunger, new_food)
              else
                {new_hunger, new_food}
              end

            %{
              agent
              | curr_hunger: new_hunger,
                food_inventory: new_food,
                gold_inventory: agent.gold_inventory + actual_dg
            }
          end)

        {grid_acc, agents_acc ++ moved_explorers ++ updated_exploiters}
      end)

    {final_grid, all_resolved}
  end

  defp satisfy_hunger(hunger, food) do
    rate = Globals.food_consumption_rate()

    if hunger > 0 and food >= rate do
      satisfy_hunger(max(0.0, hunger - rate), food - rate)
    else
      {hunger, food}
    end
  end

  defp resolve_agent_decision(agent, expected_deltas) do
    params = Math.derive_preference_params(agent)
    current_u = Math.calculate_utility(agent.food_inventory, agent.gold_inventory, params)

    exploit_u =
      Math.calculate_utility(
        agent.food_inventory + expected_deltas.df,
        agent.gold_inventory + expected_deltas.dg,
        params
      )

    # Small expected find for exploration
    explore_u = Math.calculate_utility(agent.food_inventory + 0.5, agent.gold_inventory + 0.1, params)

    exploit_marginal = exploit_u - current_u
    explore_marginal = explore_u - current_u

    if exploit_marginal > explore_marginal and exploit_marginal > 0,
      do: :exploit,
      else: :explore
  end

  defp get_adjacent_positions(%Position{x: x, y: y}, grid_width, grid_height) do
    adjs = []
    adjs = if x > 0, do: [%Position{x: x - 1, y: y} | adjs], else: adjs
    adjs = if x < grid_width - 1, do: [%Position{x: x + 1, y: y} | adjs], else: adjs
    adjs = if y > 0, do: [%Position{x: x, y: y - 1} | adjs], else: adjs
    adjs = if y < grid_height - 1, do: [%Position{x: x, y: y + 1} | adjs], else: adjs
    adjs
  end

  defp update_grid_at(grid, x, y, new_square) do
    List.update_at(grid, y, fn row ->
      List.update_at(row, x, fn _sq -> new_square end)
    end)
  end

  # Apply per-tick hunger increment, food consumption, and death
  defp apply_hunger_and_death(agents, grid, prev_tick) do
    Enum.reduce(agents, {[], grid}, fn agent, {acc, grid_acc} ->
      if agent.is_dead do
        {[agent | acc], grid_acc}
      else
        rate = Globals.food_consumption_rate()

        {final_food, final_hunger} =
          if agent.food_inventory >= rate do
            {agent.food_inventory - rate, max(0.0, agent.curr_hunger - 1)}
          else
            {agent.food_inventory, agent.curr_hunger + Globals.hunger_per_turn()}
          end

        should_die = final_hunger >= Globals.death_at_hunger()

        # Drop gold on tile when dying
        grid_acc =
          if should_die and agent.gold_inventory > 0 do
            sq = grid_acc |> Enum.at(agent.pos.y) |> Enum.at(agent.pos.x)
            updated_sq = %{sq | gold_resources: sq.gold_resources + agent.gold_inventory}
            update_grid_at(grid_acc, agent.pos.x, agent.pos.y, updated_sq)
          else
            grid_acc
          end

        updated_agent = %{
          agent
          | food_inventory: final_food,
            curr_hunger: final_hunger,
            is_dead: should_die,
            died_on_turn: if(should_die, do: prev_tick + 1, else: nil)
        }

        {[updated_agent | acc], grid_acc}
      end
    end)
    |> then(fn {agents, grid} -> {Enum.reverse(agents), grid} end)
  end

  # Reproduction: 2+ fertile agents on dirt tile spawn a baby
  defp apply_reproduction(agents, grid, prev_tick) do
    living = Enum.filter(agents, &(!&1.is_dead))

    groups = Enum.group_by(living, fn a -> {a.pos.x, a.pos.y} end)

    {babies, parent_updates} =
      Enum.reduce(groups, {[], %{}}, fn {{x, y}, occupants}, {babies_acc, updates_acc} ->
        fertile =
          Enum.filter(occupants, fn a ->
            a.curr_hunger < Globals.max_pregnancy_hunger()
          end)

        sq = grid |> Enum.at(y) |> Enum.at(x)

        if length(fertile) >= 2 and sq.type == :dirt and :rand.uniform() < Globals.reproduce_chance() do
          baby = %Agent{
            id: Init.generate_random_id(),
            pos: %Position{x: x, y: y},
            curr_hunger: Globals.starting_baby_hunger() * 1.0,
            base_greed: :rand.uniform() * 3,
            food_inventory: 0.0,
            gold_inventory: 0.0,
            is_dead: false,
            born_on_turn: prev_tick + 1,
            color: "hsl(#{:rand.uniform(360)}, 70%, 50%)"
          }

          # Tag the first two fertile parents for hunger cost
          [p1, p2 | _] = fertile
          cost = Globals.birthing_hunger_cost()

          updates_acc =
            updates_acc
            |> Map.put(p1.id, p1.curr_hunger + cost)
            |> Map.put(p2.id, p2.curr_hunger + cost)

          {[baby | babies_acc], updates_acc}
        else
          {babies_acc, updates_acc}
        end
      end)

    # Apply parent hunger costs
    updated_agents =
      Enum.map(agents, fn a ->
        case Map.get(parent_updates, a.id) do
          nil -> a
          new_hunger -> %{a | curr_hunger: new_hunger}
        end
      end)

    {updated_agents ++ babies, grid}
  end
end
