use crate::state::AppState;
use leptos::*;

/// SVG supply/demand step chart showing bids (blue) and asks (red).
#[component]
pub fn MarketGraph(state: ReadSignal<AppState>) -> impl IntoView {
    let width = 300.0_f64;
    let height = 180.0_f64;
    let pad = 30.0_f64;

    let chart_data = move || {
        let snap = state.get();
        let s = snap.snapshot.as_ref()?;

        let mut bids: Vec<f64> = s.market.bids.iter().map(|o| o.price).collect();
        let mut asks: Vec<f64> = s.market.asks.iter().map(|o| o.price).collect();

        if bids.is_empty() && asks.is_empty() {
            return None;
        }

        bids.sort_by(|a, b| b.partial_cmp(a).unwrap()); // descending
        asks.sort_by(|a, b| a.partial_cmp(b).unwrap()); // ascending

        let all_prices: Vec<f64> = bids.iter().chain(asks.iter()).copied().collect();
        let p_min = all_prices.iter().cloned().fold(f64::INFINITY, f64::min);
        let p_max = all_prices.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let p_range = (p_max - p_min).max(0.1);

        let inner_w = width - pad * 2.0;
        let inner_h = height - pad * 2.0;

        let to_x = |qty: f64, total: f64| -> f64 {
            pad + (qty / total.max(1.0)) * inner_w
        };
        let to_y = |price: f64| -> f64 {
            pad + inner_h - ((price - p_min) / p_range) * inner_h
        };

        let total = (bids.len() + asks.len()) as f64;

        // Demand (bids) step path: descending
        let mut demand_path = String::new();
        for (i, &p) in bids.iter().enumerate() {
            let x = to_x(i as f64, total);
            let x2 = to_x((i + 1) as f64, total);
            let y = to_y(p);
            if i == 0 {
                demand_path.push_str(&format!("M {x} {y}"));
            }
            demand_path.push_str(&format!(" H {x2} V {y}"));
        }

        // Supply (asks) step path: ascending
        let ask_offset = bids.len() as f64;
        let mut supply_path = String::new();
        for (i, &p) in asks.iter().enumerate() {
            let x = to_x(ask_offset + i as f64, total);
            let x2 = to_x(ask_offset + (i + 1) as f64, total);
            let y = to_y(p);
            if i == 0 {
                supply_path.push_str(&format!("M {x} {y}"));
            }
            supply_path.push_str(&format!(" H {x2} V {y}"));
        }

        Some((demand_path, supply_path))
    };

    view! {
        <div class="market-graph">
            <h3 class="chart-title">"Supply / Demand"</h3>
            <svg viewBox={format!("0 0 {width} {height}")} class="chart-svg">
                // Axes
                <line x1={pad} y1={pad} x2={pad} y2={height - pad} class="axis" />
                <line x1={pad} y1={height - pad} x2={width - pad} y2={height - pad} class="axis" />
                <text x={pad - 5.0} y={pad} class="axis-label" text-anchor="end">"P"</text>
                <text x={width - pad} y={height - pad + 14.0} class="axis-label" text-anchor="end">"Q"</text>

                {move || chart_data().map(|(dem, sup)| view! {
                    <path d={dem} class="demand-path" />
                    <path d={sup} class="supply-path" />
                })}
            </svg>
        </div>
    }
}
