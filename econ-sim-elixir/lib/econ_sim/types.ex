defmodule EconSim.Types do
  @moduledoc """
  Core data structures for the economic simulation.
  All structs are immutable value types mirroring the TypeScript originals.
  """

  defmodule Position do
    @type t :: %__MODULE__{x: integer(), y: integer()}
    defstruct [:x, :y]
  end

  defmodule Agent do
    @type t :: %__MODULE__{
            id: String.t(),
            pos: Position.t(),
            curr_hunger: float(),
            base_greed: float(),
            food_inventory: float(),
            gold_inventory: float(),
            is_dead: boolean(),
            born_on_turn: integer(),
            died_on_turn: integer() | nil,
            color: String.t()
          }
    defstruct [
      :id,
      :pos,
      curr_hunger: 0.0,
      base_greed: 0.0,
      food_inventory: 0.0,
      gold_inventory: 0.0,
      is_dead: false,
      born_on_turn: 0,
      died_on_turn: nil,
      color: "hsl(0, 70%, 50%)"
    ]
  end

  defmodule Square do
    @type square_type :: :dirt | :food | :gold
    @type t :: %__MODULE__{
            type: square_type(),
            food_resources: float(),
            gold_resources: float()
          }
    defstruct type: :dirt, food_resources: 0.0, gold_resources: 0.0
  end

  defmodule Order do
    @type order_type :: :bid | :ask
    @type t :: %__MODULE__{
            agent_id: String.t(),
            type: order_type(),
            price: float(),
            qty: float()
          }
    defstruct [:agent_id, :type, :price, :qty]
  end

  defmodule TradeEvent do
    @type t :: %__MODULE__{
            tick: integer(),
            buyer_id: String.t(),
            seller_id: String.t(),
            price: float(),
            qty: float()
          }
    defstruct [:tick, :buyer_id, :seller_id, :price, :qty]
  end

  defmodule MarketState do
    @type t :: %__MODULE__{
            bids: [Order.t()],
            asks: [Order.t()],
            last_clearing_price: float() | nil,
            volume_last_tick: float(),
            trades_last_tick: [TradeEvent.t()]
          }
    defstruct bids: [],
              asks: [],
              last_clearing_price: nil,
              volume_last_tick: 0,
              trades_last_tick: []
  end

  defmodule WorldState do
    @type t :: %__MODULE__{
            tick: integer(),
            grid: [[Square.t()]],
            agents: [Agent.t()],
            market: MarketState.t()
          }
    defstruct tick: 0, grid: [], agents: [], market: %MarketState{}
  end
end
