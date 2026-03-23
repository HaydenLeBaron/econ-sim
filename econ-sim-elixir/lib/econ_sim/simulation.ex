defmodule EconSim.Simulation do
  @moduledoc """
  GenServer managing simulation state. Holds the history of world states,
  handles play/pause/step/rewind, and broadcasts updates via PubSub.
  """
  use GenServer

  alias EconSim.{Init, Tick}

  @tick_interval 500
  @topic "simulation"

  # --- Client API ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def next_tick, do: GenServer.call(__MODULE__, :next_tick)
  def set_index(index), do: GenServer.call(__MODULE__, {:set_index, index})
  def toggle_play, do: GenServer.call(__MODULE__, :toggle_play)
  def toggle_markets, do: GenServer.call(__MODULE__, :toggle_markets)
  def reset, do: GenServer.call(__MODULE__, :reset)
  def select_agents(ids), do: GenServer.call(__MODULE__, {:select_agents, ids})

  def subscribe do
    Phoenix.PubSub.subscribe(EconSim.PubSub, @topic)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    initial = Init.generate_initial_state()

    state = %{
      history: [initial],
      curr_index: 0,
      is_playing: false,
      markets_enabled: true,
      selected_agent_ids: [],
      timer_ref: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, build_reply(state), state}
  end

  def handle_call(:next_tick, _from, state) do
    state = advance_tick(state)
    broadcast(state)
    {:reply, build_reply(state), state}
  end

  def handle_call({:set_index, index}, _from, state) do
    max_idx = length(state.history) - 1
    index = max(0, min(index, max_idx))
    state = %{state | curr_index: index, is_playing: false, timer_ref: cancel_timer(state.timer_ref)}
    broadcast(state)
    {:reply, build_reply(state), state}
  end

  def handle_call(:toggle_play, _from, state) do
    if state.is_playing do
      state = %{state | is_playing: false, timer_ref: cancel_timer(state.timer_ref)}
      broadcast(state)
      {:reply, build_reply(state), state}
    else
      ref = Process.send_after(self(), :auto_tick, @tick_interval)
      state = %{state | is_playing: true, timer_ref: ref}
      broadcast(state)
      {:reply, build_reply(state), state}
    end
  end

  def handle_call(:toggle_markets, _from, state) do
    state = %{state | markets_enabled: !state.markets_enabled}
    broadcast(state)
    {:reply, build_reply(state), state}
  end

  def handle_call(:reset, _from, _state) do
    initial = Init.generate_initial_state()

    state = %{
      history: [initial],
      curr_index: 0,
      is_playing: false,
      markets_enabled: true,
      selected_agent_ids: [],
      timer_ref: nil
    }

    broadcast(state)
    {:reply, build_reply(state), state}
  end

  def handle_call({:select_agents, ids}, _from, state) do
    state = %{state | selected_agent_ids: ids}
    broadcast(state)
    {:reply, build_reply(state), state}
  end

  @impl true
  def handle_info(:auto_tick, state) do
    if state.is_playing do
      state = advance_tick(state)
      ref = Process.send_after(self(), :auto_tick, @tick_interval)
      state = %{state | timer_ref: ref}
      broadcast(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  # --- Private Helpers ---

  defp advance_tick(state) do
    # Truncate history to current index (discard future if rewound)
    history = Enum.take(state.history, state.curr_index + 1)
    current = List.last(history)
    next = Tick.tick(current, markets_enabled: state.markets_enabled)
    %{state | history: history ++ [next], curr_index: state.curr_index + 1}
  end

  defp cancel_timer(nil), do: nil

  defp cancel_timer(ref) do
    Process.cancel_timer(ref)
    nil
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(EconSim.PubSub, @topic, {:state_updated, build_reply(state)})
  end

  defp build_reply(state) do
    current_world = Enum.at(state.history, state.curr_index)

    all_trades =
      state.history
      |> Enum.take(state.curr_index + 1)
      |> Enum.flat_map(fn ws -> ws.market.trades_last_tick end)

    %{
      world: current_world,
      curr_index: state.curr_index,
      history_length: length(state.history),
      is_playing: state.is_playing,
      markets_enabled: state.markets_enabled,
      selected_agent_ids: state.selected_agent_ids,
      all_trades: all_trades
    }
  end
end
