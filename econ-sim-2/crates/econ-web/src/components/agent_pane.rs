use crate::components::indifference_curve::IndifferenceCurve;
use crate::state::AppState;
use econ_engine::utility;
use leptos::*;

#[component]
pub fn AgentPane(state: ReadSignal<AppState>, selected_id: ReadSignal<Option<u64>>) -> impl IntoView {
    let agent = move || {
        let sid = selected_id.get()?;
        let snap = state.get().snapshot?;
        snap.agents.into_iter().find(|a| a.id.0 == sid)
    };

    view! {
        <div class="agent-pane">
            <h2 class="pane-title">"Agent Detail"</h2>
            {move || match agent() {
                None => view! {
                    <p class="no-selection">"Click an agent or select from the list to inspect."</p>
                }.into_view(),
                Some(a) => {
                    let sm = a.self_model.clone();
                    let food = a.inventory.food;
                    let gold = a.inventory.gold;
                    let p = utility::derive_params(&sm);
                    let agent_mrs = utility::mrs(food, gold, &p);

                    let sm_sig = Signal::derive(move || sm.clone());
                    let food_sig = Signal::derive(move || food);
                    let gold_sig = Signal::derive(move || gold);

                    view! {
                        <div class="agent-details">
                            <div class="agent-id">"Agent #"{a.id.0}</div>
                            <div class="detail-row">
                                <span class="detail-label">"Status"</span>
                                <span class="detail-val">
                                    {if a.died_on_turn.is_some() { "Dead" } else { "Alive" }}
                                </span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"Born turn"</span>
                                <span class="detail-val">{a.born_on_turn}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"Hunger"</span>
                                <span class="detail-val">
                                    {format!("{:.2}/{:.2}", a.self_model.hunger.current, a.self_model.hunger.max)}
                                </span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"Greed"</span>
                                <span class="detail-val">{format!("{:.3}", a.self_model.greed)}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"Food"</span>
                                <span class="detail-val">{format!("{:.3}", food)}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"Gold"</span>
                                <span class="detail-val">{format!("{:.3}", gold)}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"α (food pref)"</span>
                                <span class="detail-val">{format!("{:.3}", p.alpha)}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"β (gold pref)"</span>
                                <span class="detail-val">{format!("{:.3}", p.beta)}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">"MRS"</span>
                                <span class="detail-val">
                                    {if agent_mrs.is_finite() { format!("{:.3}", agent_mrs) } else { "∞".to_string() }}
                                </span>
                            </div>
                            <IndifferenceCurve
                                self_model=sm_sig
                                food=food_sig
                                gold=gold_sig
                            />
                        </div>
                    }.into_view()
                }
            }}
            // Agent list
            <div class="agent-list">
                <h3>"Agents"</h3>
                {move || {
                    let snap = state.get().snapshot;
                    snap.map(|s| {
                        let mut alive: Vec<_> = s.agents.iter()
                            .filter(|a| a.died_on_turn.is_none())
                            .collect::<Vec<_>>()
                            .into_iter()
                            .cloned()
                            .collect();
                        alive.sort_by(|a, b| a.id.0.cmp(&b.id.0));
                        alive.into_iter().map(|a| {
                            let p = utility::derive_params(&a.self_model);
                            let agent_mrs = utility::mrs(a.inventory.food, a.inventory.gold, &p);
                            let id_str = format!("#{}", a.id.0);
                            let hunger_str = format!("H:{:.1}", a.self_model.hunger.current);
                            let food_str = format!("F:{:.1}", a.inventory.food);
                            let gold_str = format!("G:{:.1}", a.inventory.gold);
                            let mrs_str = if agent_mrs.is_finite() {
                                format!("MRS:{:.2}", agent_mrs)
                            } else {
                                "MRS:∞".to_string()
                            };
                            view! {
                                <div class="agent-list-row">
                                    <span class="al-id">{id_str}</span>
                                    <span class="al-hunger">{hunger_str}</span>
                                    <span class="al-food">{food_str}</span>
                                    <span class="al-gold">{gold_str}</span>
                                    <span class="al-mrs">{mrs_str}</span>
                                </div>
                            }
                        }).collect_view()
                    })
                }}
            </div>
        </div>
    }
}
