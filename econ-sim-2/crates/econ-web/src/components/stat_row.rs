use leptos::*;

#[component]
pub fn StatRow(
    label: &'static str,
    values: Signal<Vec<f64>>,
) -> impl IntoView {
    let stats = move || {
        let v = values.get();
        if v.is_empty() {
            return (0.0_f64, 0.0_f64, 0.0_f64, 0.0_f64);
        }
        let mut sorted = v.clone();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let min = sorted[0];
        let max = *sorted.last().unwrap();
        let mean = sorted.iter().sum::<f64>() / sorted.len() as f64;
        let median = if sorted.len() % 2 == 0 {
            (sorted[sorted.len() / 2 - 1] + sorted[sorted.len() / 2]) / 2.0
        } else {
            sorted[sorted.len() / 2]
        };
        (min, mean, median, max)
    };

    view! {
        <div class="stat-row">
            <span class="stat-label">{label}</span>
            <span class="stat-val">"min: "{move || format!("{:.2}", stats().0)}</span>
            <span class="stat-val">"avg: "{move || format!("{:.2}", stats().1)}</span>
            <span class="stat-val">"med: "{move || format!("{:.2}", stats().2)}</span>
            <span class="stat-val">"max: "{move || format!("{:.2}", stats().3)}</span>
        </div>
    }
}
