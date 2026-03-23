use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Kind {
    Food,
    Gold,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Bundle {
    pub food: f64,
    pub gold: f64,
}

impl Bundle {
    pub fn zero() -> Self {
        Bundle { food: 0.0, gold: 0.0 }
    }

    pub fn add(&self, other: &Bundle) -> Bundle {
        Bundle {
            food: self.food + other.food,
            gold: self.gold + other.gold,
        }
    }

    pub fn scale(&self, factor: f64) -> Bundle {
        Bundle {
            food: self.food * factor,
            gold: self.gold * factor,
        }
    }
}

impl Default for Bundle {
    fn default() -> Self {
        Self::zero()
    }
}
