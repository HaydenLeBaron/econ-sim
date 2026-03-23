defmodule EconSim.Init do
  @moduledoc """
  World initialization: procedural grid generation and agent placement.
  Direct port of src/engine/init.ts.
  """

  alias EconSim.Types.{Agent, Square, MarketState, WorldState}
  alias EconSim.Globals

  @doc """
  Generates a random 9-character alphanumeric ID.
  """
  def generate_random_id do
    :crypto.strong_rand_bytes(7) |> Base.url_encode64() |> binary_part(0, 9)
  end

  @doc """
  Generates the initial world state with a grid and agents.
  Default: 20x15 grid, 50 agents.
  """
  @spec generate_initial_state(integer(), integer(), integer()) :: WorldState.t()
  def generate_initial_state(width \\ 20, height \\ 15, num_agents \\ 50) do
    grid =
      for _y <- 0..(height - 1) do
        for _x <- 0..(width - 1) do
          rand = :rand.uniform()

          cond do
            rand < 0.2 ->
              %Square{
                type: :food,
                food_resources: :rand.uniform(Globals.max_food_per_block()) * 1.0,
                gold_resources: 0.0
              }

            rand < 0.25 ->
              %Square{
                type: :gold,
                food_resources: 0.0,
                gold_resources: (:rand.uniform(100)) * 1.0
              }

            true ->
              %Square{type: :dirt, food_resources: 0.0, gold_resources: 0.0}
          end
        end
      end

    agents =
      for _i <- 1..num_agents do
        %Agent{
          id: generate_random_id(),
          pos: %EconSim.Types.Position{
            x: :rand.uniform(width) - 1,
            y: :rand.uniform(height) - 1
          },
          curr_hunger: 0.0,
          base_greed: :rand.uniform() * 10,
          food_inventory: 1.0,
          gold_inventory: 1.0,
          is_dead: false,
          born_on_turn: 0,
          color: "hsl(#{:rand.uniform(360)}, 70%, 50%)"
        }
      end

    %WorldState{
      tick: 0,
      grid: grid,
      agents: agents,
      market: %MarketState{}
    }
  end
end
