use econ_engine::{self_model::SelfModel, utility};
use leptos::*;

/// SVG showing the Cobb-Douglas indifference curve for a given self-model
/// plus the agent's current (food, gold) bundle as a dot.
#[component]
pub fn IndifferenceCurve(
    self_model: Signal<SelfModel>,
    food: Signal<f64>,
    gold: Signal<f64>,
) -> impl IntoView {
    let w = 200.0_f64;
    let h = 160.0_f64;
    let pad = 20.0_f64;
    let max_val = 15.0_f64;

    let to_x = move |f: f64| pad + (f / max_val) * (w - pad * 2.0);
    let to_y = move |g: f64| h - pad - (g / max_val) * (h - pad * 2.0);

    let curve_path = move || {
        let sm = self_model.get();
        let p = utility::derive_params(&sm);
        let f0 = food.get();
        let g0 = gold.get();
        let u0 = utility::utility(f0, g0, &p);

        // Sample the indifference curve: for each food value, solve for gold
        // U(f, g) = u0  =>  (g+1)^beta = u0 / (f+1)^alpha  =>  g = (u0/(f+1)^alpha)^(1/beta) - 1
        let n = 60usize;
        let mut path = String::new();
        let mut first = true;
        for i in 0..=n {
            let f = (i as f64 / n as f64) * max_val;
            if p.beta == 0.0 {
                continue;
            }
            let g = (u0 / (f + 1.0).powf(p.alpha)).powf(1.0 / p.beta) - 1.0;
            if g < 0.0 || g > max_val || !g.is_finite() {
                first = true;
                continue;
            }
            let x = to_x(f);
            let y = to_y(g);
            if first {
                path.push_str(&format!("M {x:.1} {y:.1}"));
                first = false;
            } else {
                path.push_str(&format!(" L {x:.1} {y:.1}"));
            }
        }
        path
    };

    view! {
        <div class="indifference-chart">
            <h4 class="chart-title">"Indifference Curve"</h4>
            <svg viewBox={format!("0 0 {w} {h}")} class="ic-svg">
                // Axes
                <line x1={pad} y1={pad} x2={pad} y2={h - pad} class="axis" />
                <line x1={pad} y1={h - pad} x2={w - pad} y2={h - pad} class="axis" />
                <text x={pad - 2.0} y={pad + 4.0} class="axis-label" font-size="8" text-anchor="end">"G"</text>
                <text x={w - pad} y={h - pad + 10.0} class="axis-label" font-size="8">"F"</text>
                // Curve
                <path d={curve_path} class="ic-curve" />
                // Current bundle dot
                <circle
                    cx={move || to_x(food.get())}
                    cy={move || to_y(gold.get())}
                    r="4"
                    class="bundle-dot"
                />
            </svg>
        </div>
    }
}
