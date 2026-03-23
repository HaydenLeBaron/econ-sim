defmodule EconSim.Market do
  @moduledoc """
  Market order generation and order book matching.
  Direct port of src/engine/market.ts.
  """

  alias EconSim.Types.{Agent, Order, TradeEvent, MarketState}
  alias EconSim.Math

  @doc """
  Generates buy/sell orders from all living agents based on their MRS.
  Agents with MRS > 1.0 are natural buyers (bid for food with gold).
  Agents with MRS < 1.0 are natural sellers (ask to sell food for gold).
  """
  @spec generate_orders([Agent.t()]) :: %{bids: [Order.t()], asks: [Order.t()]}
  def generate_orders(agents) do
    agents
    |> Enum.filter(&(!&1.is_dead))
    |> Enum.reduce(%{bids: [], asks: []}, fn agent, acc ->
      mrs = Math.calculate_mrs(agent)

      cond do
        not is_number(mrs) or mrs <= 0 ->
          acc

        mrs > 1.0 ->
          max_qty = floor(agent.gold_inventory / mrs)

          if max_qty > 0 do
            order = %Order{agent_id: agent.id, type: :bid, price: mrs, qty: max_qty * 1.0}
            %{acc | bids: [order | acc.bids]}
          else
            acc
          end

        mrs < 1.0 ->
          max_qty = agent.food_inventory

          if max_qty > 0 do
            order = %Order{agent_id: agent.id, type: :ask, price: mrs, qty: max_qty}
            %{acc | asks: [order | acc.asks]}
          else
            acc
          end

        true ->
          acc
      end
    end)
  end

  @doc """
  Resolves the market by matching bids (highest first) against asks (lowest first).
  Returns updated agents and the new market state.
  """
  @spec resolve_market([Order.t()], [Order.t()], [Agent.t()], integer()) ::
          %{updated_agents: [Agent.t()], market_state: MarketState.t()}
  def resolve_market(bids, asks, agents, tick) do
    # Keep pristine copies for UI display
    pristine_bids = bids |> Enum.sort_by(& &1.price, :desc)
    pristine_asks = asks |> Enum.sort_by(& &1.price, :asc)

    sorted_bids = bids |> Enum.sort_by(& &1.price, :desc) |> Enum.map(&Map.from_struct/1)
    sorted_asks = asks |> Enum.sort_by(& &1.price, :asc) |> Enum.map(&Map.from_struct/1)

    agent_map = Map.new(agents, fn a -> {a.id, a} end)

    {agent_map, last_clearing_price, volume, trades} =
      match_orders(sorted_bids, sorted_asks, agent_map, tick, nil, 0, [])

    updated_agents = Enum.map(agents, fn a -> Map.get(agent_map, a.id, a) end)

    %{
      updated_agents: updated_agents,
      market_state: %MarketState{
        bids: pristine_bids,
        asks: pristine_asks,
        last_clearing_price: last_clearing_price,
        volume_last_tick: volume,
        trades_last_tick: Enum.reverse(trades)
      }
    }
  end

  # Recursive order matching — mirrors the while loop from market.ts
  defp match_orders([], _asks, agent_map, _tick, lcp, vol, trades),
    do: {agent_map, lcp, vol, trades}

  defp match_orders(_bids, [], agent_map, _tick, lcp, vol, trades),
    do: {agent_map, lcp, vol, trades}

  defp match_orders(
         [bid | rest_bids] = bids,
         [ask | rest_asks] = asks,
         agent_map,
         tick,
         _lcp,
         vol,
         trades
       ) do
    cond do
      bid.price < ask.price ->
        # Spread is positive — market cleared
        {agent_map, _lcp = if(trades != [], do: List.first(trades).price, else: nil), vol, trades}

      bid.qty <= 0 ->
        match_orders(rest_bids, asks, agent_map, tick, nil, vol, trades)

      ask.qty <= 0 ->
        match_orders(bids, rest_asks, agent_map, tick, nil, vol, trades)

      true ->
        buyer = Map.get(agent_map, bid.agent_id)
        seller = Map.get(agent_map, ask.agent_id)

        if is_nil(buyer) or is_nil(seller) do
          new_bids = if is_nil(buyer), do: [%{bid | qty: 0} | rest_bids], else: bids
          new_asks = if is_nil(seller), do: [%{ask | qty: 0} | rest_asks], else: asks
          match_orders(new_bids, new_asks, agent_map, tick, nil, vol, trades)
        else
          match_price = (bid.price + ask.price) / 2
          match_volume = min(bid.qty, ask.qty)
          max_affordable = floor(buyer.gold_inventory / match_price)
          max_sellable = seller.food_inventory
          match_volume = min(match_volume, min(max_affordable * 1.0, max_sellable))

          if match_volume <= 0 do
            new_bids = if max_affordable <= 0, do: [%{bid | qty: 0} | rest_bids], else: bids
            new_asks = if max_sellable <= 0, do: [%{ask | qty: 0} | rest_asks], else: asks
            match_orders(new_bids, new_asks, agent_map, tick, nil, vol, trades)
          else
            # Execute trade
            updated_buyer = %{
              buyer
              | gold_inventory: buyer.gold_inventory - match_volume * match_price,
                food_inventory: buyer.food_inventory + match_volume
            }

            updated_seller = %{
              seller
              | gold_inventory: seller.gold_inventory + match_volume * match_price,
                food_inventory: seller.food_inventory - match_volume
            }

            agent_map =
              agent_map
              |> Map.put(buyer.id, updated_buyer)
              |> Map.put(seller.id, updated_seller)

            trade = %TradeEvent{
              tick: tick,
              buyer_id: buyer.id,
              seller_id: seller.id,
              price: match_price,
              qty: match_volume
            }

            new_bid = %{bid | qty: bid.qty - match_volume}
            new_ask = %{ask | qty: ask.qty - match_volume}

            new_bids = if new_bid.qty <= 0, do: rest_bids, else: [new_bid | rest_bids]
            new_asks = if new_ask.qty <= 0, do: rest_asks, else: [new_ask | rest_asks]

            match_orders(
              new_bids,
              new_asks,
              agent_map,
              tick,
              match_price,
              vol + match_volume,
              [trade | trades]
            )
          end
        end
    end
  end
end
