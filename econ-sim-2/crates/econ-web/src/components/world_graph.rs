use crate::state::AppState;
use econ_engine::location::Terrain;
use leptos::*;

/// Renders the directed graph world as an SVG.
/// Nodes are circles colored by terrain; edges are gray lines.
/// Agents appear as small colored dots on their location node.
#[component]
pub fn WorldGraph(state: ReadSignal<AppState>) -> impl IntoView {
    let selected_agent = create_rw_signal(None::<u64>);

    view! {
        <div class="world-graph-container">
            <svg
                class="world-svg"
                viewBox="0 0 1000 700"
                preserveAspectRatio="xMidYMid meet"
            >
                // Edges
                <For
                    each=move || {
                        let snap = state.get();
                        snap.snapshot.map(|s| {
                            s.locations.iter().flat_map(|loc| {
                                let x1 = loc.pos.0 * 900.0 + 50.0;
                                let y1 = loc.pos.1 * 600.0 + 50.0;
                                loc.neighbors.iter().map(move |&nid| {
                                    (loc.id.0, nid.0, x1, y1)
                                }).collect::<Vec<_>>()
                            }).collect::<Vec<_>>()
                        }).unwrap_or_default()
                    }
                    key=|(src, dst, _, _)| format!("{src}-{dst}")
                    children=move |(_, _, x1, y1)| {
                        // Edge coordinates resolved below via state lookup
                        view! { <line x1={x1} y1={y1} x2={x1} y2={y1} class="edge" /> }
                    }
                />
                // Render edges properly
                {move || {
                    let snap = state.get();
                    let Some(s) = snap.snapshot else { return view! { <g></g> } };

                    // Build position lookup
                    let pos_map: std::collections::HashMap<u64, (f64, f64)> = s.locations
                        .iter()
                        .map(|loc| (loc.id.0, (loc.pos.0 * 900.0 + 50.0, loc.pos.1 * 600.0 + 50.0)))
                        .collect();

                    let edges: Vec<_> = s.locations.iter().flat_map(|loc| {
                        let (x1, y1) = pos_map[&loc.id.0];
                        loc.neighbors.iter().filter_map(|nid| {
                            pos_map.get(&nid.0).map(|&(x2, y2)| (x1, y1, x2, y2))
                        }).collect::<Vec<_>>()
                    }).collect();

                    view! {
                        <g class="edges">
                            {edges.into_iter().map(|(x1, y1, x2, y2)| view! {
                                <line x1={x1} y1={y1} x2={x2} y2={y2} class="edge" />
                            }).collect_view()}
                        </g>
                    }
                }}
                // Nodes
                {move || {
                    let snap = state.get();
                    let Some(s) = snap.snapshot else { return view! { <g></g> } };

                    let _sel = selected_agent.get();

                    view! {
                        <g class="nodes">
                            {s.locations.into_iter().map(move |loc| {
                                let cx = loc.pos.0 * 900.0 + 50.0;
                                let cy = loc.pos.1 * 600.0 + 50.0;
                                let node_class = match loc.terrain {
                                    Terrain::Dirt => "node node-dirt",
                                    Terrain::Farm => "node node-farm",
                                    Terrain::Mine => "node node-mine",
                                };
                                let agent_count = loc.agent_ids.len();
                                let has_agents = agent_count > 0;
                                let _loc_id = loc.id.0;

                                view! {
                                    <g class="node-group">
                                        <circle
                                            cx={cx} cy={cy} r="14"
                                            class={node_class}
                                        />
                                        // Food/gold bar
                                        {if loc.resources.food > 0.0 || loc.resources.gold > 0.0 {
                                            let food_w = (loc.resources.food / 10.0).min(1.0) * 20.0;
                                            let gold_w = (loc.resources.gold / 10.0).min(1.0) * 20.0;
                                            view! {
                                                <rect x={cx - 10.0} y={cy + 16.0} width={food_w} height="3" class="food-bar" />
                                                <rect x={cx - 10.0} y={cy + 20.0} width={gold_w} height="3" class="gold-bar" />
                                            }.into_view()
                                        } else {
                                            view! { <g></g> }.into_view()
                                        }}
                                        // Agent dot
                                        {if has_agents {
                                            view! {
                                                <circle cx={cx + 10.0} cy={cy - 10.0} r="6"
                                                    class="agent-dot"
                                                />
                                                <text x={cx + 10.0} y={cy - 6.0}
                                                    class="agent-count"
                                                >{agent_count}</text>
                                            }.into_view()
                                        } else {
                                            view! { <g></g> }.into_view()
                                        }}
                                    </g>
                                }
                            }).collect_view()}
                        </g>
                    }
                }}
            </svg>
            // Legend
            <div class="map-legend">
                <span class="legend-item"><span class="swatch dirt"></span>"Dirt"</span>
                <span class="legend-item"><span class="swatch farm"></span>"Farm"</span>
                <span class="legend-item"><span class="swatch mine"></span>"Mine"</span>
            </div>
        </div>
    }
}
