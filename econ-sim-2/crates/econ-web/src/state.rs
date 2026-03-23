use econ_shared::{SimCommand, SimEvent, WorldSnapshot};
use gloo_net::websocket::{futures::WebSocket, Message};
use leptos::*;
use futures::{SinkExt, StreamExt};
use wasm_bindgen_futures::spawn_local;

#[derive(Clone, Default)]
pub struct AppState {
    pub snapshot: Option<WorldSnapshot>,
    pub connected: bool,
    pub error: Option<String>,
}

/// Set up the WebSocket connection and return a signal for the app state
/// and a callback for sending commands.
pub fn use_sim(ws_url: &str) -> (ReadSignal<AppState>, Callback<SimCommand>) {
    let (state, set_state) = create_signal(AppState::default());

    let ws_url = ws_url.to_string();

    // Channel for outgoing commands
    let (cmd_tx, mut cmd_rx) = futures::channel::mpsc::unbounded::<SimCommand>();

    let cmd_tx_clone = cmd_tx.clone();
    let send_cmd = Callback::new(move |cmd: SimCommand| {
        let _ = cmd_tx_clone.unbounded_send(cmd);
    });

    spawn_local(async move {
        let ws = match WebSocket::open(&ws_url) {
            Ok(ws) => ws,
            Err(e) => {
                set_state.update(|s| {
                    s.error = Some(format!("WebSocket error: {:?}", e));
                });
                return;
            }
        };

        set_state.update(|s| s.connected = true);

        let (mut write, mut read) = ws.split();

        // Receive task
        let set_state_recv = set_state;
        spawn_local(async move {
            while let Some(msg) = read.next().await {
                match msg {
                    Ok(Message::Text(text)) => {
                        match serde_json::from_str::<SimEvent>(&text) {
                            Ok(SimEvent::StateUpdate(snap)) => {
                                set_state_recv.update(|s| s.snapshot = Some(snap));
                            }
                            Ok(SimEvent::Error { message }) => {
                                set_state_recv.update(|s| s.error = Some(message));
                            }
                            Err(e) => {
                                leptos::logging::warn!("Parse error: {e}");
                            }
                        }
                    }
                    Err(e) => {
                        set_state_recv.update(|s| {
                            s.connected = false;
                            s.error = Some(format!("{:?}", e));
                        });
                        break;
                    }
                    _ => {}
                }
            }
            set_state_recv.update(|s| s.connected = false);
        });

        // Send task
        while let Some(cmd) = cmd_rx.next().await {
            if let Ok(text) = serde_json::to_string(&cmd) {
                if write.send(Message::Text(text)).await.is_err() {
                    break;
                }
            }
        }
    });

    (state, send_cmd)
}
