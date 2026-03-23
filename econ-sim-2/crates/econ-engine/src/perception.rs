use crate::agent_id::AgentId;
use crate::digraph::DiGraph;
use crate::world::World;
use crate::world_model::WorldModel;

/// Build agent `aid`'s subjective world model from reality.
///
/// Visibility rules:
/// - The agent always sees its current vertex (full state including all agent_ids).
/// - For each outgoing edge from the current vertex:
///   - If edge.visible = true: include the destination vertex (terrain + resources)
///     and the edge weight. agent_ids at the destination are NOT included
///     (agents can't see other agents' internal state at remote locations).
///   - If edge.visible = false: neither vertex nor edge appears.
/// - No transitive visibility (1-hop only).
pub fn see(aid: AgentId, world: &World) -> WorldModel {
    // Find this agent's current location
    let agent = match world.agents.iter().find(|a| a.id == aid && a.is_alive()) {
        Some(a) => a,
        None => return DiGraph::empty(),
    };

    let loc_id = agent.location;
    let mut model: WorldModel = DiGraph::empty();

    // Always see current location fully
    if let Some(loc) = world.graph.vertex_state(loc_id) {
        model.insert_vertex(loc_id, loc.clone());
    }

    // Check visible outgoing edges
    for (neighbor_id, edge) in world.graph.neighbors(loc_id) {
        if edge.visible {
            // Add the edge
            model.add_edge_mut(loc_id, neighbor_id, edge.clone());

            // Add neighbor vertex (terrain + resources, but no agent_ids — agents can't
            // see other agents' internal state at remote locations)
            if let Some(neighbor_loc) = world.graph.vertex_state(neighbor_id) {
                if !model.contains_vertex(neighbor_id) {
                    let mut visible_loc = neighbor_loc.clone();
                    visible_loc.agent_ids = Vec::new(); // strip other agents' presence
                    model.insert_vertex(neighbor_id, visible_loc);
                }
            }
        }
    }

    model
}
