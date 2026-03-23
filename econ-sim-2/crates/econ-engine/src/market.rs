use crate::agent::Agent;
use crate::agent_id::AgentId;
use crate::utility;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Order {
    pub agent_id: AgentId,
    pub price: f64,
    pub quantity: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Side {
    Bid,
    Ask,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Trade {
    pub buyer: AgentId,
    pub seller: AgentId,
    pub price: f64,
    pub quantity: f64,
    pub turn: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct MarketState {
    pub bids: Vec<Order>,
    pub asks: Vec<Order>,
    pub clearing_price: Option<f64>,
    pub volume: f64,
    pub history: Vec<Trade>,
}

/// For each living agent, generate a bid or ask based on MRS vs 1.0.
pub fn generate_orders(agents: &[Agent]) -> Vec<(Order, Side)> {
    let mut orders = Vec::new();
    for agent in agents.iter().filter(|a| a.is_alive()) {
        let p = utility::derive_params(&agent.self_model);
        let food = agent.inventory.food;
        let gold = agent.inventory.gold;
        let agent_mrs = utility::mrs(food, gold, &p);

        if agent_mrs > 1.0 {
            // Values food more than gold — willing to buy food with gold
            orders.push((
                Order {
                    agent_id: agent.id,
                    price: agent_mrs,
                    quantity: 1.0,
                },
                Side::Bid,
            ));
        } else if agent_mrs < 1.0 {
            // Values gold more than food — willing to sell food for gold
            orders.push((
                Order {
                    agent_id: agent.id,
                    price: agent_mrs,
                    quantity: 1.0,
                },
                Side::Ask,
            ));
        }
        // MRS == 1.0 → indifferent, no order
    }
    orders
}

/// Match bids against asks via double auction.
/// Returns updated MarketState and a list of (agent_id, food_delta, gold_delta).
pub fn resolve(
    orders: Vec<(Order, Side)>,
    turn: i32,
) -> (MarketState, Vec<(AgentId, f64, f64)>) {
    let mut bids: Vec<Order> = orders
        .iter()
        .filter(|(_, s)| *s == Side::Bid)
        .map(|(o, _)| o.clone())
        .collect();
    let mut asks: Vec<Order> = orders
        .iter()
        .filter(|(_, s)| *s == Side::Ask)
        .map(|(o, _)| o.clone())
        .collect();

    // Sort bids descending, asks ascending
    bids.sort_by(|a, b| b.price.partial_cmp(&a.price).unwrap_or(std::cmp::Ordering::Equal));
    asks.sort_by(|a, b| a.price.partial_cmp(&b.price).unwrap_or(std::cmp::Ordering::Equal));

    let mut trades: Vec<Trade> = Vec::new();
    let mut deltas: Vec<(AgentId, f64, f64)> = Vec::new();
    let mut clearing_price = None;
    let mut volume = 0.0;

    let mut bi = 0;
    let mut ai = 0;

    while bi < bids.len() && ai < asks.len() {
        let bid = &bids[bi];
        let ask = &asks[ai];
        if bid.price < ask.price {
            break;
        }
        let exec_price = (bid.price + ask.price) / 2.0;
        let qty = bid.quantity.min(ask.quantity);

        trades.push(Trade {
            buyer: bid.agent_id,
            seller: ask.agent_id,
            price: exec_price,
            quantity: qty,
            turn,
        });

        // buyer: pays gold, receives food
        deltas.push((bid.agent_id, qty, -(exec_price * qty)));
        // seller: pays food, receives gold
        deltas.push((ask.agent_id, -qty, exec_price * qty));

        clearing_price = Some(exec_price);
        volume += qty;
        bi += 1;
        ai += 1;
    }

    let state = MarketState {
        bids: bids.clone(),
        asks: asks.clone(),
        clearing_price,
        volume,
        history: trades,
    };

    (state, deltas)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::self_model::{Hunger, SelfModel};
    use crate::world_model::WorldModel;

    fn make_agent(id_val: u64, food: f64, gold: f64, hunger: f64, greed: f64) -> Agent {
        Agent {
            id: AgentId(id_val),
            born_on_turn: 0,
            died_on_turn: None,
            self_model: SelfModel {
                hunger: Hunger { current: hunger, max: 10.0 },
                greed,
            },
            world_model: WorldModel::empty(),
            inventory: crate::resource::Bundle { food, gold },
            location: crate::digraph::VertexId(1),
        }
    }

    #[test]
    fn trade_occurs_when_bid_above_ask() {
        // Agent A: hungry (high MRS → bids high), Agent B: greedy (low MRS → asks low)
        let hungry = make_agent(1, 0.0, 10.0, 5.0, 0.0);
        let greedy = make_agent(2, 5.0, 0.0, 0.0, 3.0);
        let agents = vec![hungry, greedy];
        let orders = generate_orders(&agents);
        assert_eq!(orders.len(), 2);
        let (state, deltas) = resolve(orders, 0);
        assert!(state.history.len() > 0);
        assert!(state.volume > 0.0);
        assert_eq!(deltas.len(), 2);
    }
}
