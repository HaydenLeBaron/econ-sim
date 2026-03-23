use crate::state::AppState;
use crate::components::stat_row::StatRow;
use econ_engine::utility;
use leptos::*;

#[component]
pub fn EconomyPane(state: ReadSignal<AppState>) -> impl IntoView {
    let alive_count = move || {
        state.get().snapshot.as_ref()
            .map(|s| s.agents.iter().filter(|a| a.died_on_turn.is_none()).count())
            .unwrap_or(0)
    };

    let food_values = Signal::derive(move || {
        state.get().snapshot.as_ref()
            .map(|s| s.agents.iter()
                .filter(|a| a.died_on_turn.is_none())
                .map(|a| a.inventory.food)
                .collect::<Vec<_>>())
            .unwrap_or_default()
    });

    let gold_values = Signal::derive(move || {
        state.get().snapshot.as_ref()
            .map(|s| s.agents.iter()
                .filter(|a| a.died_on_turn.is_none())
                .map(|a| a.inventory.gold)
                .collect::<Vec<_>>())
            .unwrap_or_default()
    });

    let hunger_values = Signal::derive(move || {
        state.get().snapshot.as_ref()
            .map(|s| s.agents.iter()
                .filter(|a| a.died_on_turn.is_none())
                .map(|a| a.self_model.hunger.current)
                .collect::<Vec<_>>())
            .unwrap_or_default()
    });

    let mrs_values = Signal::derive(move || {
        state.get().snapshot.as_ref()
            .map(|s| s.agents.iter()
                .filter(|a| a.died_on_turn.is_none())
                .map(|a| {
                    let p = utility::derive_params(&a.self_model);
                    utility::mrs(a.inventory.food, a.inventory.gold, &p)
                })
                .filter(|v: &f64| v.is_finite())
                .collect::<Vec<_>>())
            .unwrap_or_default()
    });

    let market_stats = move || {
        state.get().snapshot.as_ref().map(|s| {
            let price = s.market.clearing_price.map(|p| format!("{:.3}", p)).unwrap_or_else(|| "—".into());
            let vol = format!("{:.2}", s.market.volume);
            let trades = s.market.history.len();
            (price, vol, trades)
        })
    };

    view! {
        <div class="economy-pane">
            <h2 class="pane-title">"Economy"</h2>
            <div class="stat-block">
                <div class="stat-row">
                    <span class="stat-label">"Living agents"</span>
                    <span class="stat-val big">{alive_count}</span>
                </div>
            </div>
            <div class="stat-block">
                <h3>"Inventory"</h3>
                <StatRow label="Food" values=food_values />
                <StatRow label="Gold" values=gold_values />
            </div>
            <div class="stat-block">
                <h3>"Welfare"</h3>
                <StatRow label="Hunger" values=hunger_values />
                <StatRow label="MRS" values=mrs_values />
            </div>
            <div class="stat-block">
                <h3>"Market (last turn)"</h3>
                {move || market_stats().map(|(price, vol, trades)| view! {
                    <div class="stat-row">
                        <span class="stat-label">"Clearing price"</span>
                        <span class="stat-val">{price}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">"Volume"</span>
                        <span class="stat-val">{vol}</span>
                    </div>
                    <div class="stat-row">
                        <span class="stat-label">"Trades"</span>
                        <span class="stat-val">{trades}</span>
                    </div>
                })}
            </div>
        </div>
    }
}
