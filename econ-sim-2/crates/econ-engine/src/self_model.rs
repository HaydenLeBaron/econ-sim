use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Hunger {
    pub current: f64,
    pub max: f64,
}

pub type Greed = f64;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SelfModel {
    pub hunger: Hunger,
    pub greed: Greed,
}
