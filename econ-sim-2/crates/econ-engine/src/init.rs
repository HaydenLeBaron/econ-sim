use crate::agent::Agent;
use crate::agent_id::AgentId;
use crate::digraph::{DiGraph, VertexId};
use crate::location::{Location, Terrain};
use crate::path::Path;
use crate::resource::Bundle;
use crate::self_model::{Hunger, SelfModel};
use crate::sim_params::SimParams;
use crate::world::World;
use crate::world_model::WorldModel;
use rand::Rng;

/// Generate a world with an irregular DiGraph topology.
///
/// Strategy:
/// 1. Scatter `num_locations` points randomly in [0,1)^2.
/// 2. Connect each point to its 3 nearest neighbors (bidirectional edges).
/// 3. Ensure full connectivity via BFS; connect any isolated component to
///    the main component with a single bridging edge.
/// 4. Assign terrain: 75% Dirt, 20% Farm, 5% Mine.
/// 5. Place `num_agents` agents at randomly chosen vertices.
pub fn generate(num_locations: usize, num_agents: usize, params: &SimParams) -> World {
    let mut rng = rand::thread_rng();

    // 1. Generate random positions
    let positions: Vec<(f64, f64)> = (0..num_locations)
        .map(|_| (rng.gen::<f64>(), rng.gen::<f64>()))
        .collect();

    // 2. Assign terrain
    let terrains: Vec<Terrain> = (0..num_locations)
        .map(|_| {
            let r: f64 = rng.gen();
            if r < 0.75 {
                Terrain::Dirt
            } else if r < 0.95 {
                Terrain::Farm
            } else {
                Terrain::Mine
            }
        })
        .collect();

    // 3. Create vertex IDs
    let ids: Vec<VertexId> = (0..num_locations).map(|_| VertexId::fresh()).collect();

    // 4. Build graph
    let mut graph: DiGraph<Location, Path> = DiGraph::empty();
    for i in 0..num_locations {
        graph.insert_vertex(ids[i], Location::new(terrains[i], positions[i]));
    }

    // 5. Connect each vertex to its K nearest neighbors (K=3 or num_locations-1 if smaller)
    let k = 3_usize.min(num_locations.saturating_sub(1));
    for i in 0..num_locations {
        let mut dists: Vec<(usize, f64)> = (0..num_locations)
            .filter(|&j| j != i)
            .map(|j| {
                let dx = positions[i].0 - positions[j].0;
                let dy = positions[i].1 - positions[j].1;
                (j, dx * dx + dy * dy)
            })
            .collect();
        dists.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        for (j, _) in dists.iter().take(k) {
            graph.add_edge_mut(ids[i], ids[*j], Path::default());
            graph.add_edge_mut(ids[*j], ids[i], Path::default());
        }
    }

    // 6. Ensure full connectivity via BFS
    if num_locations > 1 {
        ensure_connected(&mut graph, &ids, &positions);
    }

    // 7. Place agents at random locations
    let mut agents: Vec<Agent> = Vec::new();
    for _ in 0..num_agents {
        let loc_idx = rng.gen_range(0..num_locations);
        let loc_id = ids[loc_idx];
        let greed: f64 = rng.gen_range(0.0..2.0);

        let agent = Agent {
            id: AgentId::fresh(),
            born_on_turn: 0,
            died_on_turn: None,
            self_model: SelfModel {
                hunger: Hunger { current: 0.0, max: params.max_hunger_default },
                greed,
            },
            world_model: WorldModel::empty(),
            inventory: Bundle::zero(),
            location: loc_id,
        };
        // Register agent at location
        graph.update_vertex(loc_id, |loc| {
            loc.agent_ids.push(agent.id);
        });
        agents.push(agent);
    }

    World { graph, agents, turn: 0 }
}

/// BFS from the first vertex; for any unreachable vertex, add a bridging
/// bidirectional edge to the nearest already-reachable vertex.
fn ensure_connected(
    graph: &mut DiGraph<Location, Path>,
    ids: &[VertexId],
    positions: &[(f64, f64)],
) {
    use std::collections::VecDeque;

    if ids.is_empty() {
        return;
    }

    let mut visited = std::collections::HashSet::new();
    let mut queue = VecDeque::new();
    queue.push_back(ids[0]);
    visited.insert(ids[0]);

    while let Some(v) = queue.pop_front() {
        for (n, _) in graph.neighbors(v) {
            if visited.insert(n) {
                queue.push_back(n);
            }
        }
    }

    // For each unvisited vertex, connect to nearest visited vertex
    for (i, &id) in ids.iter().enumerate() {
        if visited.contains(&id) {
            continue;
        }
        // Find nearest visited vertex
        let nearest = ids
            .iter()
            .enumerate()
            .filter(|(_, &vid)| visited.contains(&vid))
            .min_by(|(ai, _), (bi, _)| {
                let da = dist(positions[i], positions[*ai]);
                let db = dist(positions[i], positions[*bi]);
                da.partial_cmp(&db).unwrap()
            })
            .map(|(_, &vid)| vid);

        if let Some(target) = nearest {
            graph.add_edge_mut(id, target, Path::default());
            graph.add_edge_mut(target, id, Path::default());
            visited.insert(id);
        }
    }
}

fn dist(a: (f64, f64), b: (f64, f64)) -> f64 {
    let dx = a.0 - b.0;
    let dy = a.1 - b.1;
    dx * dx + dy * dy
}
