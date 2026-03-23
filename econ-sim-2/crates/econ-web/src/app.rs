use crate::components::{
    agent_pane::AgentPane,
    economy_pane::EconomyPane,
    market_graph::MarketGraph,
    timeline::Timeline,
    trade_log::TradeLog,
    world_graph::WorldGraph,
};
use crate::state::use_sim;
use leptos::*;

#[component]
pub fn App() -> impl IntoView {
    // Detect hostname for WebSocket URL
    let ws_url = {
        let window = web_sys::window().expect("no window");
        let host = window.location().host().unwrap_or_else(|_| "localhost:3000".to_string());
        let protocol = window.location().protocol().unwrap_or_else(|_| "http:".to_string());
        let ws_proto = if protocol == "https:" { "wss:" } else { "ws:" };
        format!("{ws_proto}//{host}/ws")
    };

    let (state, send_cmd) = use_sim(&ws_url);
    let selected_agent = create_rw_signal(None::<u64>);

    view! {
        <div class="app">
            <header class="app-header">
                <h1>"Econ-Sim 2"</h1>
                <span class="connection-badge">
                    {move || if state.get().connected { "● Connected" } else { "○ Disconnected" }}
                </span>
            </header>
            <main class="app-main">
                // Left column: economy stats + market
                <aside class="left-pane">
                    <EconomyPane state=state />
                    <MarketGraph state=state />
                </aside>

                // Center: world graph + timeline + trade log
                <section class="center-pane">
                    <WorldGraph state=state />
                    <Timeline state=state send_cmd=send_cmd />
                    <TradeLog state=state />
                </section>

                // Right column: agent detail
                <aside class="right-pane">
                    <AgentPane state=state selected_id=selected_agent.read_only() />
                </aside>
            </main>
        </div>
    }
}
