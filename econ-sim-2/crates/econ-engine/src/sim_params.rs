use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SimParams {
    pub hunger_per_turn: f64,
    pub max_hunger_default: f64,
    pub food_regen_per_turn: f64,
    pub gold_regen_per_turn: f64,
    pub max_resource_per_location: f64,
    pub gold_harvest_limit_per_agent: f64,
    pub explore_expected_food: f64,
    pub explore_expected_gold: f64,
    pub fertility_threshold: usize,
    pub market_enabled: bool,
}

impl Default for SimParams {
    fn default() -> Self {
        SimParams {
            hunger_per_turn: 0.3,
            max_hunger_default: 10.0,
            food_regen_per_turn: 1.0,
            gold_regen_per_turn: 1.0,
            max_resource_per_location: 10.0,
            gold_harvest_limit_per_agent: 1.0,
            explore_expected_food: 0.5,
            explore_expected_gold: 0.1,
            fertility_threshold: 2,
            market_enabled: true,
        }
    }
}
