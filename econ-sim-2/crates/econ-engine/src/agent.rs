use crate::agent_id::AgentId;
use crate::digraph::VertexId;
use crate::resource::Bundle;
use crate::self_model::SelfModel;
use crate::world_model::WorldModel;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Agent {
    pub id: AgentId,
    pub born_on_turn: i32,
    /// None while alive; Some(turn) when dead.
    pub died_on_turn: Option<i32>,
    pub self_model: SelfModel,
    pub world_model: WorldModel,
    pub inventory: Bundle,
    pub location: VertexId,
}

impl Agent {
    pub fn is_alive(&self) -> bool {
        self.died_on_turn.is_none()
    }
}
