use crate::agent::Agent;
use crate::agent_id::AgentId;
use crate::decision::{self, Action};
use crate::digraph::VertexId;
use crate::location::Terrain;
use crate::market::{self, MarketState};
use crate::perception;
use crate::resource::Bundle;
use crate::self_model::{Hunger, SelfModel};
use crate::sim_params::SimParams;
use crate::world::World;
use crate::world_model::WorldModel;
use std::collections::HashMap;

/// Advance the world by one simulation turn (9 phases).
pub fn tick(mut world: World, params: &SimParams) -> (World, MarketState) {
    phase_1_regen(&mut world, params);
    phase_2_perception(&mut world);
    let decisions = phase_3_decision(&world, params);
    phase_4_resolve(&mut world, &decisions, params);
    phase_5_consumption(&mut world, params);
    phase_6_death(&mut world);
    phase_7_reproduction(&mut world, params);
    let market_state = phase_8_market(&mut world, params);
    world.turn += 1;
    (world, market_state)
}

// ── Phase 1: Environment Regeneration ────────────────────────────────────────

fn phase_1_regen(world: &mut World, params: &SimParams) {
    let vertex_ids: Vec<VertexId> = world.graph.vertex_ids();
    for id in vertex_ids {
        world.graph.update_vertex(id, |loc| match loc.terrain {
            Terrain::Farm => {
                loc.resources.food =
                    (loc.resources.food + params.food_regen_per_turn)
                        .min(params.max_resource_per_location);
            }
            Terrain::Mine => {
                loc.resources.gold =
                    (loc.resources.gold + params.gold_regen_per_turn)
                        .min(params.max_resource_per_location);
            }
            Terrain::Dirt => {}
        });
    }
}

// ── Phase 2: Perception ───────────────────────────────────────────────────────

fn phase_2_perception(world: &mut World) {
    // We need the world immutably to build world models, then patch agents.
    // Collect (agent_id, new_world_model) first, then apply.
    let updates: Vec<(AgentId, WorldModel)> = world
        .agents
        .iter()
        .filter(|a| a.is_alive())
        .map(|a| (a.id, perception::see(a.id, world)))
        .collect();

    for (aid, wm) in updates {
        if let Some(agent) = world.agents.iter_mut().find(|a| a.id == aid) {
            agent.world_model = wm;
        }
    }
}

// ── Phase 3: Decision ─────────────────────────────────────────────────────────

fn phase_3_decision(world: &World, params: &SimParams) -> HashMap<AgentId, Action> {
    world
        .agents
        .iter()
        .filter(|a| a.is_alive())
        .map(|a| (a.id, decision::decide(a, params)))
        .collect()
}

// ── Phase 4: Action Resolution ────────────────────────────────────────────────

fn phase_4_resolve(
    world: &mut World,
    decisions: &HashMap<AgentId, Action>,
    params: &SimParams,
) {
    // Group agents by location for fair exploitation
    let mut exploiters_by_loc: HashMap<VertexId, Vec<usize>> = HashMap::new();
    let mut explorers: Vec<(usize, VertexId)> = Vec::new();

    for (idx, agent) in world.agents.iter().enumerate() {
        if !agent.is_alive() {
            continue;
        }
        match decisions.get(&agent.id) {
            Some(Action::Exploit) => {
                exploiters_by_loc.entry(agent.location).or_default().push(idx);
            }
            Some(Action::Explore(dest)) => {
                explorers.push((idx, *dest));
            }
            None => {}
        }
    }

    // Exploitation: distribute resources equally
    for (loc_id, agent_indices) in &exploiters_by_loc {
        let n = agent_indices.len() as f64;
        let (food_share, gold_share_raw) = {
            let loc = match world.graph.vertex_state(*loc_id) {
                Some(l) => l,
                None => continue,
            };
            (loc.resources.food / n, loc.resources.gold / n)
        };

        let gold_share = gold_share_raw.min(params.gold_harvest_limit_per_agent);
        let actual_food_taken = food_share * n;
        let actual_gold_taken = gold_share * n;

        // Deduct from location
        world.graph.update_vertex(*loc_id, |loc| {
            loc.resources.food = (loc.resources.food - actual_food_taken).max(0.0);
            loc.resources.gold = (loc.resources.gold - actual_gold_taken).max(0.0);
        });

        // Give to agents
        for &idx in agent_indices {
            world.agents[idx].inventory.food += food_share;
            world.agents[idx].inventory.gold += gold_share;
        }
    }

    // Exploration: verify gates and move
    for (idx, dest) in explorers {
        let (agent_loc, agent_gold, agent_hunger) = {
            let a = &world.agents[idx];
            (a.location, a.inventory.gold, a.self_model.hunger.current)
        };

        let edge = match world.graph.edge_weight(agent_loc, dest) {
            Some(e) => e.clone(),
            None => continue, // edge doesn't exist in reality
        };

        // Gate predicates
        if agent_gold < edge.gold_cost {
            continue; // wasted turn
        }
        if agent_hunger < edge.min_hunger || agent_hunger > edge.max_hunger {
            continue; // wasted turn
        }

        // Deduct costs and move
        let agent = &mut world.agents[idx];
        agent.inventory.gold -= edge.gold_cost;
        agent.self_model.hunger.current += edge.hunger_cost;

        let old_loc = agent.location;
        agent.location = dest;

        // Update location agent_ids
        world.graph.update_vertex(old_loc, |loc| {
            loc.agent_ids.retain(|&id| id != world.agents[idx].id);
        });
        world.graph.update_vertex(dest, |loc| {
            loc.agent_ids.push(world.agents[idx].id);
        });
    }
}

// ── Phase 5: Consumption and Hunger ───────────────────────────────────────────

fn phase_5_consumption(world: &mut World, params: &SimParams) {
    for agent in world.agents.iter_mut().filter(|a| a.is_alive()) {
        let hunger = agent.self_model.hunger.current;
        let food_to_eat = agent.inventory.food.min(hunger);
        agent.inventory.food -= food_to_eat;
        agent.self_model.hunger.current -= food_to_eat;

        // If still hungry after eating, hunger increases
        if agent.self_model.hunger.current > 0.0 {
            agent.self_model.hunger.current += params.hunger_per_turn;
        }
    }
}

// ── Phase 6: Death ────────────────────────────────────────────────────────────

fn phase_6_death(world: &mut World) {
    let turn = world.turn;
    let mut dead_drops: Vec<(VertexId, f64)> = Vec::new();

    for agent in world.agents.iter_mut().filter(|a| a.is_alive()) {
        if agent.self_model.hunger.current > agent.self_model.hunger.max {
            agent.died_on_turn = Some(turn);
            dead_drops.push((agent.location, agent.inventory.gold));
            agent.inventory = Bundle::zero();
        }
    }

    // Drop gold onto locations, remove from agent_ids
    for (loc_id, gold) in dead_drops {
        world.graph.update_vertex(loc_id, |loc| {
            loc.resources.gold += gold;
        });
    }

    // Remove dead agents from location agent_ids lists
    let dead_ids: Vec<AgentId> = world
        .agents
        .iter()
        .filter(|a| a.died_on_turn == Some(turn))
        .map(|a| a.id)
        .collect();
    for dead_id in dead_ids {
        let loc = world
            .agents
            .iter()
            .find(|a| a.id == dead_id)
            .map(|a| a.location);
        if let Some(loc_id) = loc {
            world.graph.update_vertex(loc_id, |loc| {
                loc.agent_ids.retain(|&id| id != dead_id);
            });
        }
    }
}

// ── Phase 7: Reproduction ─────────────────────────────────────────────────────

fn phase_7_reproduction(world: &mut World, params: &SimParams) {
    let turn = world.turn;
    let vertex_ids: Vec<VertexId> = world.graph.vertex_ids();
    let mut new_agents: Vec<Agent> = Vec::new();

    for loc_id in vertex_ids {
        let terrain = match world.graph.vertex_state(loc_id) {
            Some(loc) => loc.terrain,
            None => continue,
        };
        if terrain != Terrain::Dirt {
            continue;
        }

        // Collect fertile agents at this location
        let fertile_indices: Vec<usize> = world
            .agents
            .iter()
            .enumerate()
            .filter(|(_, a)| {
                a.is_alive() && a.location == loc_id && a.inventory.food >= 1.0
            })
            .map(|(i, _)| i)
            .collect();

        if fertile_indices.len() < params.fertility_threshold {
            continue;
        }

        // Compute mean greed of fertile parents
        let mean_greed = fertile_indices
            .iter()
            .map(|&i| world.agents[i].self_model.greed)
            .sum::<f64>()
            / fertile_indices.len() as f64;

        // Spawn one child
        let child_id = AgentId::fresh();
        let child = Agent {
            id: child_id,
            born_on_turn: turn,
            died_on_turn: None,
            self_model: SelfModel {
                hunger: Hunger { current: 0.0, max: params.max_hunger_default },
                greed: mean_greed,
            },
            world_model: WorldModel::empty(),
            inventory: Bundle::zero(),
            location: loc_id,
        };
        new_agents.push(child);

        // Each fertile parent pays 0.5 food
        for &i in &fertile_indices {
            world.agents[i].inventory.food -= 0.5;
        }

        // Register child at location
        world.graph.update_vertex(loc_id, |loc| {
            loc.agent_ids.push(child_id);
        });
    }

    world.agents.extend(new_agents);
}

// ── Phase 8: Market ───────────────────────────────────────────────────────────

fn phase_8_market(world: &mut World, params: &SimParams) -> MarketState {
    if !params.market_enabled {
        return MarketState::default();
    }

    let living_owned: Vec<Agent> = world.agents.iter().filter(|a| a.is_alive()).cloned().collect();
    let orders = market::generate_orders(&living_owned);
    let (state, deltas) = market::resolve(orders, world.turn);

    // Apply inventory deltas
    for (aid, food_delta, gold_delta) in deltas {
        if let Some(agent) = world.agents.iter_mut().find(|a| a.id == aid) {
            agent.inventory.food = (agent.inventory.food + food_delta).max(0.0);
            agent.inventory.gold = (agent.inventory.gold + gold_delta).max(0.0);
        }
    }

    state
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::init;

    #[test]
    fn tick_does_not_panic() {
        let params = SimParams::default();
        let world = init::generate(20, 10, &params);
        let (world2, _) = tick(world, &params);
        assert!(world2.turn == 1);
    }

    #[test]
    fn hundred_ticks_stable() {
        let params = SimParams::default();
        let mut world = init::generate(50, 20, &params);
        for _ in 0..100 {
            let (w, _) = tick(world, &params);
            world = w;
        }
        assert!(world.turn == 100);
        // Some agents should still be alive (Farm/Mine locations replenish)
        let alive = world.agents.iter().filter(|a| a.is_alive()).count();
        println!("Alive after 100 ticks: {}", alive);
    }
}
