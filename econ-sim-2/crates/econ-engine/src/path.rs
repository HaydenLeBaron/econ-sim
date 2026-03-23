use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Path {
    pub travel_time: i32,
    pub gold_cost: f64,
    pub hunger_cost: f64,
    pub min_hunger: f64,
    pub max_hunger: f64,
    pub visible: bool,
}

impl Default for Path {
    fn default() -> Self {
        Path {
            travel_time: 1,
            gold_cost: 0.0,
            hunger_cost: 0.0,
            min_hunger: 0.0,
            max_hunger: f64::INFINITY,
            visible: true,
        }
    }
}
