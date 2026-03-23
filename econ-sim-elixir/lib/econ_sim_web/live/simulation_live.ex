defmodule EconSimWeb.SimulationLive do
  use EconSimWeb, :live_view

  alias EconSim.{Simulation, Math}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Simulation.subscribe()

    sim_state = Simulation.get_state()

    {:ok, assign_sim_state(socket, sim_state)}
  end

  defp assign_sim_state(socket, sim_state) do
    assign(socket,
      world: sim_state.world,
      curr_index: sim_state.curr_index,
      history_length: sim_state.history_length,
      is_playing: sim_state.is_playing,
      markets_enabled: sim_state.markets_enabled,
      selected_agent_ids: sim_state.selected_agent_ids,
      all_trades: sim_state.all_trades,
      leaderboard_limit: 10
    )
  end

  @impl true
  def handle_info({:state_updated, sim_state}, socket) do
    {:noreply, assign_sim_state(socket, sim_state)}
  end

  @impl true
  def handle_event("next_tick", _params, socket) do
    Simulation.next_tick()
    {:noreply, socket}
  end

  def handle_event("toggle_play", _params, socket) do
    Simulation.toggle_play()
    {:noreply, socket}
  end

  def handle_event("set_index", %{"value" => value}, socket) do
    {idx, _} = Integer.parse(value)
    Simulation.set_index(idx)
    {:noreply, socket}
  end

  def handle_event("toggle_markets", _params, socket) do
    Simulation.toggle_markets()
    {:noreply, socket}
  end

  def handle_event("select_agent", %{"id" => id}, socket) do
    Simulation.select_agents([id])
    {:noreply, socket}
  end

  def handle_event("select_agents", %{"ids" => ids}, socket) do
    id_list = String.split(ids, ",")
    Simulation.select_agents(id_list)
    {:noreply, socket}
  end

  def handle_event("set_leaderboard_limit", %{"value" => val}, socket) do
    {limit, _} = Integer.parse(val)
    {:noreply, assign(socket, leaderboard_limit: limit)}
  end

  def handle_event("reset", _params, socket) do
    Simulation.reset()
    {:noreply, socket}
  end

  # --- Template ---

  @impl true
  def render(assigns) do
    living = Enum.filter(assigns.world.agents, &(!&1.is_dead))
    dead = Enum.filter(assigns.world.agents, & &1.is_dead)

    selected_agents =
      Enum.filter(assigns.world.agents, fn a ->
        a.id in assigns.selected_agent_ids
      end)

    # Compute economy stats
    stats = compute_economy_stats(living, dead, assigns.world)

    assigns =
      assigns
      |> Map.put(:living, living)
      |> Map.put(:dead, dead)
      |> Map.put(:selected_agents, selected_agents)
      |> Map.put(:stats, stats)

    ~H"""
    <div class="app-container">
      <!-- LEFT: Economy Pane -->
      <aside class="inspector economy-pane">
        <h2>Global Economy</h2>

        <!-- Macro Supply -->
        <div class="macro-supply">
          <h3 class="section-header">Macro Supply Constraints</h3>
          <div class="mono-stats">
            <div>
              <span class="gold-text">Gold Supply (<%= format_num(@stats.total_gold_supply) %>)</span>
              <br/>
              <span class="dim">= Mines (<%= format_num(@stats.total_gold_in_grid) %>) + Inv (<%= format_num(@stats.total_gold_inv) %>)</span>
            </div>
            <div>
              <span class="green-text">Food Supply (<%= format_num(@stats.total_food_supply) %>)</span>
              <br/>
              <span class="dim">= Farms (<%= format_num(@stats.total_food_in_grid) %>) + Inv (<%= format_num(@stats.total_food_inv) %>)</span>
            </div>
          </div>
        </div>

        <!-- Market -->
        <div class="market-overview">
          <div class="market-header">
            <h3 class="section-header" style="margin:0">Global Market</h3>
            <label class="market-toggle">
              <input type="checkbox" checked={@markets_enabled} phx-click="toggle_markets" /> Enabled
            </label>
          </div>

          <%= if @markets_enabled do %>
            <div class="market-stats">
              <div class="stat-row-inline">
                <span class="stat-label">Last Price (P)</span>
                <span class="stat-val gold-text">
                  <%= if @world.market.last_clearing_price, do: format_num(@world.market.last_clearing_price), else: "-" %>
                </span>
              </div>
              <div class="stat-row-inline">
                <span class="stat-label">Volume (Tick)</span>
                <span class="stat-val"><%= @world.market.volume_last_tick %></span>
              </div>
              <div class="market-graph-label">Last Turn's Supply & Demand</div>
              <%= render_market_graph(assigns) %>

              <div class="order-book">
                <div class="order-side">
                  <div class="order-header green-text">LAST TURN'S BIDS (Px - Qty)</div>
                  <%= for bid <- Enum.take(@world.market.bids, 5) do %>
                    <div class="order-row">
                      <span><%= format_num(bid.price) %></span>
                      <span><%= format_num(bid.qty) %></span>
                    </div>
                  <% end %>
                  <%= if @world.market.bids == [] do %>
                    <div class="dim mono">Empty</div>
                  <% end %>
                </div>
                <div class="order-side">
                  <div class="order-header gold-text">LAST TURN'S ASKS (Px - Qty)</div>
                  <%= for ask <- Enum.take(@world.market.asks, 5) do %>
                    <div class="order-row">
                      <span><%= format_num(ask.price) %></span>
                      <span><%= format_num(ask.qty) %></span>
                    </div>
                  <% end %>
                  <%= if @world.market.asks == [] do %>
                    <div class="dim mono">Empty</div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Stats Grid -->
        <div class="stat-grid compact">
          <div class="stat-box">
            <span class="stat-label">Population</span>
            <span class="stat-val"><%= length(@living) %></span>
          </div>
          <div class="stat-box">
            <span class="stat-label">Total Dead</span>
            <span class="stat-val"><%= length(@dead) %></span>
          </div>
          <%= render_stat_row("Age", @stats.ages, assigns) %>
          <%= render_stat_row("Lifespan", @stats.lifespans, assigns) %>
          <%= render_stat_row("Hunger", @stats.hungers, assigns) %>
          <%= render_stat_row("Greed", @stats.greeds, assigns) %>
          <%= render_stat_row("Food Inv", @stats.foods, assigns) %>
          <%= render_stat_row("Gold Inv", @stats.golds, assigns) %>
          <%= render_stat_row("Utility (U)", @stats.utils, assigns) %>
          <%= render_stat_row("MRS", @stats.mrss, assigns) %>
          <%= render_stat_row("MU_F", @stats.mufs, assigns) %>
          <%= render_stat_row("MU_G", @stats.mugs, assigns) %>
        </div>

        <!-- Leaderboard -->
        <div class="leaderboard">
          <div class="leaderboard-header">
            <h3>Wealthiest Agents</h3>
            <div class="leaderboard-limit">
              Top: <input type="number" value={@leaderboard_limit} phx-change="set_leaderboard_limit" phx-value-value={@leaderboard_limit} style="width:40px;background:rgba(0,0,0,0.3);border:1px solid var(--panel-border);color:white;padding:2px 4px;border-radius:4px;font-size:0.75rem" />
            </div>
          </div>
          <div class="leaderboard-list">
            <%= for {agent, i} <- @living |> Enum.sort_by(&(-(&1.food_inventory + &1.gold_inventory))) |> Enum.take(@leaderboard_limit) |> Enum.with_index(1) do %>
              <div class="leaderboard-row" phx-click="select_agent" phx-value-id={agent.id}>
                <div class="lb-rank"><%= i %>.</div>
                <div class="lb-swatch" style={"background-color:#{agent.color}"}></div>
                <div class="lb-id"><%= String.slice(agent.id, 0, 6) %></div>
                <div class="lb-values">
                  <span class="green-text"><%= format_num(agent.food_inventory) %>f</span>
                  <span class="gold-text"><%= format_num(agent.gold_inventory) %>g</span>
                  <span class="lb-total">(<%= format_num(agent.food_inventory + agent.gold_inventory) %>)</span>
                </div>
              </div>
            <% end %>
            <%= if @living == [] do %>
              <div class="dim" style="font-size:0.75rem">No living agents.</div>
            <% end %>
          </div>
        </div>
      </aside>

      <!-- CENTER: Main Content -->
      <main class="main-content">
        <header class="header">
          <h1>Economic Simulation Engine</h1>
        </header>

        <!-- Trade Log -->
        <%= if @all_trades != [] do %>
          <div class="trade-log-pane">
            <div class="trade-log-inner">
              <%= for {t, i} <- @all_trades |> Enum.reverse() |> Enum.take(100) |> Enum.with_index() do %>
                <div class="trade-row" id={"trade-#{i}"}>
                  <span class="dim" style="width:45px">[T<%= String.pad_leading("#{t.tick}", 3, "0") %>]</span>
                  <span class="green-text clickable" phx-click="select_agent" phx-value-id={t.buyer_id}>
                    <%= String.slice(t.buyer_id, 0, 6) %>
                  </span>
                  <span>bought</span>
                  <span class="gold-text bold"><%= t.qty %>f</span>
                  <span>from</span>
                  <span class="gold-text clickable" phx-click="select_agent" phx-value-id={t.seller_id}>
                    <%= String.slice(t.seller_id, 0, 6) %>
                  </span>
                  <span>for</span>
                  <span class="amber-text bold"><%= format_num(t.qty * t.price) %>g</span>
                  <span class="dim">(@ <%= format_num(t.price) %>/ea)</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Grid -->
        <section class="board-wrapper">
          <div class="grid" style={"grid-template-columns:repeat(#{grid_width(@world)},40px);grid-template-rows:repeat(#{grid_height(@world)},40px)"}>
            <%= for {row, y} <- Enum.with_index(@world.grid) do %>
              <%= for {sq, x} <- Enum.with_index(row) do %>
                <% agents_here = Enum.filter(@world.agents, fn a -> a.pos.x == x and a.pos.y == y end) %>
                <% living_here = Enum.filter(agents_here, &(!&1.is_dead)) %>
                <% dead_here = Enum.filter(agents_here, & &1.is_dead) %>
                <div class={"square #{sq.type}"}>
                  <%= if sq.food_resources > 0 do %>
                    <span class="resource-food"><%= trunc_num(sq.food_resources) %>f</span>
                  <% end %>
                  <%= if sq.gold_resources > 0 do %>
                    <span class="resource-gold"><%= trunc_num(sq.gold_resources) %></span>
                  <% end %>

                  <!-- Living agents -->
                  <%= if length(living_here) >= 5 do %>
                    <div class={"agent grouped living #{if Enum.any?(living_here, &(&1.id in @selected_agent_ids)), do: "selected", else: ""}"}
                         phx-click="select_agents" phx-value-ids={Enum.map_join(living_here, ",", & &1.id)}
                         style="z-index:10">
                      <%= length(living_here) %>
                    </div>
                  <% else %>
                    <%= for {agent, i} <- Enum.with_index(living_here) do %>
                      <div class={"agent living #{if agent.id in @selected_agent_ids, do: "selected", else: ""}"}
                           phx-click="select_agent" phx-value-id={agent.id}
                           style={"background-color:#{agent.color};#{if i > 0, do: "transform:translate(#{i*4}px,#{i*4}px);", else: ""}z-index:#{10+i}"}>
                      </div>
                    <% end %>
                  <% end %>

                  <!-- Dead agents -->
                  <% dead_offset_x = if living_here != [], do: 10, else: 0 %>
                  <% dead_offset_y = if living_here != [], do: -10, else: 0 %>
                  <%= if length(dead_here) >= 5 do %>
                    <div class={"agent grouped dead #{if Enum.any?(dead_here, &(&1.id in @selected_agent_ids)), do: "selected", else: ""}"}
                         phx-click="select_agents" phx-value-ids={Enum.map_join(dead_here, ",", & &1.id)}
                         style={"transform:translate(#{dead_offset_x}px,#{dead_offset_y}px);z-index:5"}>
                      <%= length(dead_here) %>
                    </div>
                  <% else %>
                    <%= for {agent, i} <- Enum.with_index(dead_here) do %>
                      <div class={"agent dead #{if agent.id in @selected_agent_ids, do: "selected", else: ""}"}
                           phx-click="select_agent" phx-value-id={agent.id}
                           style={"transform:translate(#{dead_offset_x + i*4}px,#{dead_offset_y + i*4}px);z-index:#{5+i}"}>
                        <span class="dead-mark">X</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </section>

        <!-- Timeline Controls -->
        <section class="timeline">
          <div class="controls">
            <button phx-click="toggle_play"><%= if @is_playing, do: "Pause", else: "Play" %></button>
            <button phx-click="next_tick" disabled={@is_playing} style="margin-left:0.5rem">Step Forward</button>
            <button phx-click="reset" style="margin-left:0.5rem">Reset</button>
          </div>
          <div class="slider-container">
            <input type="range" min="0" max={@history_length - 1} value={@curr_index}
                   phx-change="set_index" phx-value-value={@curr_index} />
            <span class="tick-display">Tick <%= @world.tick %></span>
          </div>
        </section>
      </main>

      <!-- RIGHT: Agent Pane -->
      <aside class="inspector agent-pane">
        <%= if @selected_agents == [] do %>
          <div class="inspector-placeholder">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10" />
              <path d="M12 16v-4" />
              <path d="M12 8h.01" />
            </svg>
            <p>Select an agent to view their economic preferences</p>
          </div>
        <% else %>
          <%= if length(@selected_agents) == 1 do %>
            <% agent = hd(@selected_agents) %>
            <div class="accordion-header" style="border:none">
              <div class="agent-color-swatch" style={"background-color:#{agent.color};border-color:#{agent.color}"}></div>
              <h2 style="margin:0">Agent <%= agent.id %></h2>
            </div>
            <%= render_single_agent_stats(agent, assigns) %>
          <% else %>
            <h2><%= length(@selected_agents) %> Grouped Agents</h2>
            <div class="agent-accordion">
              <%= for agent <- @selected_agents do %>
                <div class="accordion-item">
                  <div class="accordion-header">
                    <div class="agent-color-swatch" style={"background-color:#{agent.color};border-color:#{agent.color}"}></div>
                    <h3 style="margin:0;font-size:1rem">Agent <%= agent.id %></h3>
                    <%= if agent.is_dead do %>
                      <span class="dead-badge">DEAD</span>
                    <% end %>
                  </div>
                  <%= render_single_agent_stats(agent, assigns) %>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </aside>
    </div>
    """
  end

  # --- Helper Components ---

  defp render_single_agent_stats(agent, assigns) do
    prefs = Math.derive_preference_params(agent)
    mrs = Math.calculate_mrs(agent)
    total_u = Math.calculate_utility(agent.food_inventory, agent.gold_inventory, prefs)
    mu_f = Math.calculate_mu_food(agent)
    mu_g = Math.calculate_mu_gold(agent)
    curve = Math.generate_indifference_curve(agent, 20)

    max_food = max(4, ceil(agent.food_inventory * 2.5))
    max_gold = max(4, ceil(agent.gold_inventory * 2.5))

    svg_w = 260
    svg_h = 260
    pad = 35

    assigns =
      assigns
      |> Map.put(:agent, agent)
      |> Map.put(:prefs, prefs)
      |> Map.put(:mrs, mrs)
      |> Map.put(:total_u, total_u)
      |> Map.put(:mu_f, mu_f)
      |> Map.put(:mu_g, mu_g)
      |> Map.put(:curve, curve)
      |> Map.put(:max_food, max_food)
      |> Map.put(:max_gold, max_gold)
      |> Map.put(:svg_w, svg_w)
      |> Map.put(:svg_h, svg_h)
      |> Map.put(:pad, pad)

    ~H"""
    <div class="agent-stats">
      <div class="stat-grid compact">
        <div class="stat-box"><span class="stat-label">Born On</span><span class="stat-val"><%= @agent.born_on_turn %></span></div>
        <div class="stat-box"><span class="stat-label">Died On</span><span class="stat-val"><%= @agent.died_on_turn || "-" %></span></div>
        <div class="stat-box"><span class="stat-label">Hunger</span><span class="stat-val"><%= format_num(@agent.curr_hunger) %></span></div>
        <div class="stat-box"><span class="stat-label">Greed</span><span class="stat-val"><%= format_num(@agent.base_greed) %></span></div>
        <div class="stat-box"><span class="stat-label">Food Inv</span><span class="stat-val"><%= format_num(@agent.food_inventory) %></span></div>
        <div class="stat-box"><span class="stat-label">Gold Inv</span><span class="stat-val"><%= format_num(@agent.gold_inventory) %></span></div>
      </div>
    </div>

    <div class="preference-curve">
      <h3>Economic Parameters</h3>
      <div class="stat-grid compact" style="margin-top:0;margin-bottom:2rem">
        <div class="stat-box"><span class="stat-label">α (Food)</span><span class="stat-val"><%= format_num(@prefs.alpha) %></span></div>
        <div class="stat-box"><span class="stat-label">β (Gold)</span><span class="stat-val"><%= format_num(@prefs.beta) %></span></div>
        <div class="stat-box"><span class="stat-label">Total Utility (U)</span><span class="stat-val accent"><%= format_large(@total_u) %></span></div>
        <div class="stat-box"><span class="stat-label">MU_F (Food)</span><span class="stat-val"><%= format_num(@mu_f) %></span></div>
        <div class="stat-box"><span class="stat-label">MU_G (Gold)</span><span class="stat-val"><%= format_num(@mu_g) %></span></div>
        <div class="stat-box"><span class="stat-label">MRS</span><span class="stat-val amber-text"><%= format_num(@mrs) %></span></div>
      </div>

      <h3>Indifference Curve</h3>
      <div class="curve-chart">
        <span class="axis-label y">Gold</span>
        <span class="axis-label x">Food</span>
        <svg width="100%" height="100%" viewBox={"0 0 #{@svg_w} #{@svg_h}"}>
          <line x1={@pad} y1={@pad} x2={@pad} y2={@svg_h - @pad} stroke="rgba(255,255,255,0.2)" stroke-width="2" />
          <line x1={@pad} y1={@svg_h - @pad} x2={@svg_w - @pad} y2={@svg_h - @pad} stroke="rgba(255,255,255,0.2)" stroke-width="2" />

          <%= for i <- 1..4 do %>
            <% val = round(i * @max_food / 4) %>
            <% sx = @pad + val / @max_food * (@svg_w - 2 * @pad) %>
            <line x1={sx} y1={@svg_h - @pad} x2={sx} y2={@svg_h - @pad + 5} stroke="rgba(255,255,255,0.5)" stroke-width="1" />
            <text x={sx} y={@svg_h - @pad + 18} fill="rgba(255,255,255,0.5)" font-size="10" text-anchor="middle"><%= val %></text>
          <% end %>

          <%= for i <- 1..4 do %>
            <% val = round(i * @max_gold / 4) %>
            <% sy = @svg_h - @pad - min(val, @max_gold) / @max_gold * (@svg_h - 2 * @pad) %>
            <line x1={@pad - 5} y1={sy} x2={@pad} y2={sy} stroke="rgba(255,255,255,0.5)" stroke-width="1" />
            <text x={@pad - 8} y={sy + 3} fill="rgba(255,255,255,0.5)" font-size="10" text-anchor="end"><%= val %></text>
          <% end %>

          <path d={build_curve_path(@curve, @max_food, @max_gold, @svg_w, @svg_h, @pad)} fill="none" stroke="var(--accent)" stroke-width="3" />
          <circle cx={@pad + @agent.food_inventory / @max_food * (@svg_w - 2 * @pad)}
                  cy={@svg_h - @pad - min(@agent.gold_inventory, @max_gold) / @max_gold * (@svg_h - 2 * @pad)}
                  r="6" fill={@agent.color} />
        </svg>
      </div>
    </div>
    """
  end

  defp render_stat_row(label, nums, assigns) when nums == [] do
    assigns = Map.put(assigns, :label, label)

    ~H"""
    <div class="stat-box">
      <span class="stat-label"><%= @label %></span>
      <span class="stat-val">-</span>
    </div>
    """
  end

  defp render_stat_row(label, nums, assigns) do
    sorted = Enum.sort(nums)
    min_v = hd(sorted)
    max_v = List.last(sorted)
    len = length(sorted)
    mid = div(len, 2)

    med =
      if rem(len, 2) != 0,
        do: Enum.at(sorted, mid),
        else: (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2

    mean = Enum.sum(nums) / len

    assigns =
      assigns
      |> Map.put(:label, label)
      |> Map.put(:min_v, min_v)
      |> Map.put(:max_v, max_v)
      |> Map.put(:med, med)
      |> Map.put(:mean, mean)

    ~H"""
    <div class="stat-box" style="padding:0.5rem 0.25rem">
      <span class="stat-label"><%= @label %></span>
      <span class="stat-val" style="display:flex;gap:0.5rem">
        <span title="Minimum"><span class="mini-label">MIN</span><%= format_num(@min_v) %></span>
        <span title="Mean"><span class="mini-label">AVG</span><%= format_num(@mean) %></span>
        <span title="Median" class="accent"><span class="mini-label">MED</span><%= format_num(@med) %></span>
        <span title="Maximum"><span class="mini-label">MAX</span><%= format_num(@max_v) %></span>
      </span>
    </div>
    """
  end

  defp render_market_graph(assigns) do
    bids = assigns.world.market.bids |> Enum.sort_by(& &1.price, :desc)
    asks = assigns.world.market.asks |> Enum.sort_by(& &1.price, :asc)

    {_cum, demand_points} =
      Enum.reduce(bids, {0, []}, fn b, {cum, pts} ->
        new_cum = cum + b.qty
        {new_cum, pts ++ [%{price: b.price, qty: new_cum}]}
      end)

    {_cum, supply_points} =
      Enum.reduce(asks, {0, []}, fn a, {cum, pts} ->
        new_cum = cum + a.qty
        {new_cum, pts ++ [%{price: a.price, qty: new_cum}]}
      end)

    cum_demand = if demand_points != [], do: List.last(demand_points).qty, else: 0
    cum_supply = if supply_points != [], do: List.last(supply_points).qty, else: 0
    max_qty = max(max(cum_demand, cum_supply), 10)

    all_prices =
      Enum.map(bids, & &1.price) ++ Enum.map(asks, & &1.price)

    max_p = if all_prices != [], do: Enum.max(all_prices), else: 5
    max_p = max(max_p, 5)

    svg_w = 260
    svg_h = 120
    pad = 15

    demand_path = build_step_path(demand_points, max_qty, max_p, svg_w, svg_h, pad)
    supply_path = build_step_path(supply_points, max_qty, max_p, svg_w, svg_h, pad)

    assigns =
      assigns
      |> Map.put(:demand_path, demand_path)
      |> Map.put(:supply_path, supply_path)
      |> Map.put(:svg_w, svg_w)
      |> Map.put(:svg_h, svg_h)
      |> Map.put(:mpad, pad)

    ~H"""
    <svg width="100%" height={@svg_h} viewBox={"0 0 #{@svg_w} #{@svg_h}"} style="background:rgba(0,0,0,0.2);border-radius:4px;margin-top:0.5rem">
      <%= if @demand_path != "" do %>
        <path d={@demand_path} fill="none" stroke="#4ade80" stroke-width="2" />
      <% end %>
      <%= if @supply_path != "" do %>
        <path d={@supply_path} fill="none" stroke="#fbbf24" stroke-width="2" />
      <% end %>
      <line x1={@mpad} y1={@svg_h - @mpad} x2={@svg_w - @mpad} y2={@svg_h - @mpad} stroke="rgba(255,255,255,0.2)" stroke-width="1" />
      <line x1={@mpad} y1={@mpad} x2={@mpad} y2={@svg_h - @mpad} stroke="rgba(255,255,255,0.2)" stroke-width="1" />
      <text x={@svg_w - @mpad} y={@svg_h - @mpad + 10} fill="rgba(255,255,255,0.5)" font-size="8" text-anchor="end">Qty</text>
      <text x={@mpad - 5} y={@mpad + 5} fill="rgba(255,255,255,0.5)" font-size="8" text-anchor="end">P</text>
      <text x={@svg_w - @mpad - 40} y={@mpad + 5} fill="#4ade80" font-size="8">Demand</text>
      <text x={@svg_w - @mpad - 40} y={@mpad + 15} fill="#fbbf24" font-size="8">Supply</text>
    </svg>
    """
  end

  # --- Pure helpers ---

  defp build_step_path([], _max_qty, _max_p, _w, _h, _pad), do: ""

  defp build_step_path(points, max_qty, max_p, w, h, pad) do
    map_x = fn q -> pad + q / max_qty * (w - 2 * pad) end
    map_y = fn p -> h - pad - min(p, max_p) / max_p * (h - 2 * pad) end

    first = hd(points)

    # Build step path with horizontal steps between price levels
    points_with_next = Enum.zip(points, tl(points) ++ [nil])

    {final_path, _} =
      Enum.reduce(points_with_next, {"M #{map_x.(0)} #{map_y.(first.price)}", nil}, fn
        {pt, nil}, {acc, _prev} ->
          {acc <> " L #{map_x.(pt.qty)} #{map_y.(pt.price)}", pt}

        {pt, next_pt}, {acc, _prev} ->
          acc = acc <> " L #{map_x.(pt.qty)} #{map_y.(pt.price)}"
          acc = acc <> " L #{map_x.(pt.qty)} #{map_y.(next_pt.price)}"
          {acc, pt}
      end)

    final_path
  end

  defp build_curve_path(curve, max_food, max_gold, svg_w, svg_h, pad) do
    curve
    |> Enum.with_index()
    |> Enum.map(fn {pt, i} ->
      x = pad + pt.x / max_food * (svg_w - 2 * pad)
      y = svg_h - pad - min(pt.y, max_gold) / max_gold * (svg_h - 2 * pad)
      if i == 0, do: "M #{x} #{y}", else: "L #{x} #{y}"
    end)
    |> Enum.join(" ")
  end

  defp compute_economy_stats(living, dead, world) do
    ages = Enum.map(living, fn a -> world.tick - a.born_on_turn end)
    hungers = Enum.map(living, & &1.curr_hunger)
    greeds = Enum.map(living, & &1.base_greed)
    foods = Enum.map(living, & &1.food_inventory)
    golds = Enum.map(living, & &1.gold_inventory)

    utils =
      Enum.map(living, fn a ->
        prefs = Math.derive_preference_params(a)
        Math.calculate_utility(a.food_inventory, a.gold_inventory, prefs)
      end)

    mrss = Enum.map(living, &Math.calculate_mrs/1)
    mufs = Enum.map(living, &Math.calculate_mu_food/1)
    mugs = Enum.map(living, &Math.calculate_mu_gold/1)
    lifespans = Enum.map(dead, fn a -> (a.died_on_turn || 0) - a.born_on_turn end)

    {total_food_in_grid, total_gold_in_grid} =
      Enum.reduce(world.grid, {0.0, 0.0}, fn row, {f_acc, g_acc} ->
        Enum.reduce(row, {f_acc, g_acc}, fn sq, {f, g} ->
          {f + sq.food_resources, g + sq.gold_resources}
        end)
      end)

    total_food_inv = Enum.sum(foods)
    total_gold_inv = Enum.sum(golds)

    %{
      ages: ages,
      hungers: hungers,
      greeds: greeds,
      foods: foods,
      golds: golds,
      utils: utils,
      mrss: mrss,
      mufs: mufs,
      mugs: mugs,
      lifespans: lifespans,
      total_food_in_grid: total_food_in_grid,
      total_gold_in_grid: total_gold_in_grid,
      total_food_inv: total_food_inv,
      total_gold_inv: total_gold_inv,
      total_food_supply: total_food_in_grid + total_food_inv,
      total_gold_supply: total_gold_in_grid + total_gold_inv
    }
  end

  defp grid_width(world) do
    case world.grid do
      [row | _] -> length(row)
      _ -> 0
    end
  end

  defp grid_height(world), do: length(world.grid)

  defp format_num(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 1)
  defp format_num(n) when is_integer(n), do: Integer.to_string(n)
  defp format_num(nil), do: "-"

  defp format_large(n) when is_float(n) do
    if n > 1000,
      do: :erlang.float_to_binary(n, decimals: 0),
      else: :erlang.float_to_binary(n, decimals: 1)
  end

  defp format_large(n), do: format_num(n)

  defp trunc_num(n) when is_float(n) do
    rounded = Float.round(n, 2)
    if rounded == trunc(rounded), do: trunc(rounded), else: rounded
  end

  defp trunc_num(n), do: n
end
