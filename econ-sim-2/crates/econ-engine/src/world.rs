use crate::agent::Agent;
use crate::digraph::DiGraph;
use crate::location::Location;
use crate::path::Path;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct World {
    pub graph: DiGraph<Location, Path>,
    /// All agents that have ever existed (living + dead).
    pub agents: Vec<Agent>,
    pub turn: i32,
}
