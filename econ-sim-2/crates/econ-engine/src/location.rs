use crate::agent_id::AgentId;
use crate::resource::Bundle;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Terrain {
    Dirt,
    Farm,
    Mine,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Location {
    pub terrain: Terrain,
    pub resources: Bundle,
    pub agent_ids: Vec<AgentId>,
    /// 2D position for rendering only — the simulation never uses this for logic.
    pub pos: (f64, f64),
}

impl Location {
    pub fn new(terrain: Terrain, pos: (f64, f64)) -> Self {
        Location {
            terrain,
            resources: Bundle::zero(),
            agent_ids: Vec::new(),
            pos,
        }
    }
}
