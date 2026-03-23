use crate::state::AppState;
use econ_shared::SimCommand;
use leptos::*;

#[component]
pub fn Timeline(
    state: ReadSignal<AppState>,
    send_cmd: Callback<SimCommand>,
) -> impl IntoView {
    let playing = create_rw_signal(false);
    let interval_ms = create_rw_signal(300u64);

    let on_step = {
        let send = send_cmd;
        move |_| send.call(SimCommand::Step)
    };

    let on_play = {
        let send = send_cmd;
        let playing = playing;
        let interval_ms = interval_ms;
        move |_| {
            if playing.get() {
                playing.set(false);
                send.call(SimCommand::Pause);
            } else {
                playing.set(true);
                send.call(SimCommand::Play { interval_ms: interval_ms.get() });
            }
        }
    };

    let on_reset = {
        let send = send_cmd;
        let playing = playing;
        move |_| {
            playing.set(false);
            send.call(SimCommand::Init { num_locations: 50, num_agents: 20 });
        }
    };

    view! {
        <div class="timeline">
            <div class="timeline-controls">
                <button class="btn" on:click=on_reset>"Reset"</button>
                <button class="btn" on:click=on_step>"Step"</button>
                <button class="btn btn-primary" on:click=on_play>
                    {move || if playing.get() { "Pause" } else { "Play" }}
                </button>
            </div>
            <div class="timeline-info">
                <span class="turn-label">
                    "Turn: " {move || state.get().snapshot.as_ref().map(|s| s.turn).unwrap_or(0)}
                </span>
                <label class="speed-label">
                    "Speed (ms): "
                    <input
                        type="range" min="50" max="2000" step="50"
                        prop:value={move || interval_ms.get()}
                        on:input=move |ev| {
                            if let Ok(v) = event_target_value(&ev).parse::<u64>() {
                                interval_ms.set(v);
                            }
                        }
                    />
                    {move || interval_ms.get()}"ms"
                </label>
            </div>
        </div>
    }
}
