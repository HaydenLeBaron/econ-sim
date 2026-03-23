use crate::state::AppState;
use leptos::*;

#[component]
pub fn TradeLog(state: ReadSignal<AppState>) -> impl IntoView {
    let trades = move || {
        state.get().snapshot.as_ref()
            .map(|s| s.market.history.clone())
            .unwrap_or_default()
    };

    view! {
        <div class="trade-log">
            <h3 class="pane-title">"Trade Log (last turn)"</h3>
            <div class="trade-list">
                {move || {
                    let t = trades();
                    if t.is_empty() {
                        view! { <p class="no-trades">"No trades this turn."</p> }.into_view()
                    } else {
                        t.iter().map(|tr| view! {
                            <div class="trade-entry">
                                <span class="trade-turn">"T"{tr.turn}</span>
                                <span class="trade-buyer">"B#{"{tr.buyer.0}"}"</span>
                                <span class="trade-arrow">"→"</span>
                                <span class="trade-seller">"S#{"{tr.seller.0}"}"</span>
                                <span class="trade-qty">{format!("{:.2}", tr.quantity)}"f"</span>
                                <span class="trade-price">"@"{format!("{:.3}", tr.price)}"g"</span>
                            </div>
                        }).collect_view().into_view()
                    }
                }}
            </div>
        </div>
    }
}
