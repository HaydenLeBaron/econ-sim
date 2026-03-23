use crate::agent::Agent;
use crate::digraph::VertexId;
use crate::sim_params::SimParams;
use crate::utility;

#[derive(Clone, Debug)]
pub enum Action {
    Exploit,
    Explore(VertexId),
}

/// Decide the best action for an agent by comparing expected utility.
///
/// For Exploit: expected gain = fair share of visible resources at current location.
/// For Explore(v): expected gain = (explore_expected_food, explore_expected_gold).
/// Choose the action with highest expected utility. Ties favor Exploit.
pub fn decide(agent: &Agent, params: &SimParams) -> Action {
    let p = utility::derive_params(&agent.self_model);
    let inv = &agent.inventory;

    // Expected utility after Exploit
    let current_loc = agent.world_model.vertex_state(agent.location);
    let (exploit_food, exploit_gold) = match current_loc {
        Some(loc) => {
            let n = loc.agent_ids.len().max(1) as f64;
            (
                inv.food + loc.resources.food / n,
                (inv.gold + loc.resources.gold / n).min(inv.gold + params.gold_harvest_limit_per_agent),
            )
        }
        None => (inv.food, inv.gold),
    };
    let exploit_utility = utility::utility(exploit_food, exploit_gold, &p);

    let mut best_action = Action::Exploit;
    let mut best_utility = exploit_utility;

    // Compare against each reachable visible neighbor
    for (neighbor_id, edge) in agent.world_model.neighbors(agent.location) {
        if !edge.visible {
            continue;
        }
        // Check gate predicates
        let hunger = agent.self_model.hunger.current;
        if inv.gold < edge.gold_cost {
            continue;
        }
        if hunger < edge.min_hunger || hunger > edge.max_hunger {
            continue;
        }

        let explore_food = inv.food + params.explore_expected_food;
        let explore_gold = (inv.gold - edge.gold_cost + params.explore_expected_gold).max(0.0);
        let explore_utility = utility::utility(explore_food, explore_gold, &p);

        if explore_utility > best_utility {
            best_utility = explore_utility;
            best_action = Action::Explore(neighbor_id);
        }
    }

    best_action
}
