use econ_engine::{
    agent_id::AgentId,
    digraph::VertexId,
    location::Terrain,
    market::MarketState,
    resource::Bundle,
    self_model::SelfModel,
    sim_params::SimParams,
};
use serde::{Deserialize, Serialize};

// ── Snapshots (server → client) ──────────────────────────────────────────────

/// Lightweight view of a single location for rendering.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LocationSnapshot {
    pub id: VertexId,
    pub terrain: Terrain,
    pub resources: Bundle,
    pub agent_ids: Vec<AgentId>,
    /// 2D position for rendering [0,1)^2.
    pub pos: (f64, f64),
    /// Neighbour vertex IDs (for drawing edges).
    pub neighbors: Vec<VertexId>,
}

/// Lightweight view of a single agent.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AgentSnapshot {
    pub id: AgentId,
    pub born_on_turn: i32,
    pub died_on_turn: Option<i32>,
    pub self_model: SelfModel,
    pub inventory: Bundle,
    pub location: VertexId,
}

/// Full world state snapshot sent over WebSocket each tick.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct WorldSnapshot {
    pub turn: i32,
    pub locations: Vec<LocationSnapshot>,
    pub agents: Vec<AgentSnapshot>,
    pub market: MarketState,
}

// ── Commands (client → server) ────────────────────────────────────────────────

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SimCommand {
    Init { num_locations: usize, num_agents: usize },
    Step,
    Play { interval_ms: u64 },
    Pause,
    UpdateParams(SimParams),
}

// ── Events (server → client) ──────────────────────────────────────────────────

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SimEvent {
    StateUpdate(WorldSnapshot),
    Error { message: String },
}

// ── Conversion helpers ────────────────────────────────────────────────────────

use econ_engine::world::World;

pub fn world_to_snapshot(world: &World, market: &MarketState) -> WorldSnapshot {
    let locations = world
        .graph
        .vertices()
        .into_iter()
        .map(|(id, loc)| {
            let neighbors = world
                .graph
                .neighbors(id)
                .into_iter()
                .map(|(nid, _)| nid)
                .collect();
            LocationSnapshot {
                id,
                terrain: loc.terrain,
                resources: loc.resources,
                agent_ids: loc.agent_ids.clone(),
                pos: loc.pos,
                neighbors,
            }
        })
        .collect();

    let agents = world
        .agents
        .iter()
        .map(|a| AgentSnapshot {
            id: a.id,
            born_on_turn: a.born_on_turn,
            died_on_turn: a.died_on_turn,
            self_model: a.self_model.clone(),
            inventory: a.inventory,
            location: a.location,
        })
        .collect();

    WorldSnapshot {
        turn: world.turn,
        locations,
        agents,
        market: market.clone(),
    }
}
