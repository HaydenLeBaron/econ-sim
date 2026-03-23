use crate::sim_runner::SimRunner;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::Response,
};
use econ_shared::{SimCommand, SimEvent};
use futures::{sink::SinkExt, stream::StreamExt};

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(runner): State<SimRunner>,
) -> Response {
    ws.on_upgrade(move |socket| handle_socket(socket, runner))
}

async fn handle_socket(socket: WebSocket, runner: SimRunner) {
    let (mut sink, mut stream) = socket.split();
    let mut rx = runner.rx.clone();

    // Task: push state updates to the client
    let push_runner = runner.clone();
    let push_task = tokio::spawn(async move {
        let _ = push_runner; // keep runner alive
        loop {
            if rx.changed().await.is_err() {
                break;
            }
            let snap = rx.borrow().clone();
            if let Some(snap) = snap {
                let event = SimEvent::StateUpdate(snap);
                match serde_json::to_string(&event) {
                    Ok(text) => {
                        if sink.send(Message::Text(text.into())).await.is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        let err = SimEvent::Error { message: e.to_string() };
                        if let Ok(text) = serde_json::to_string(&err) {
                            let _ = sink.send(Message::Text(text.into())).await;
                        }
                        break;
                    }
                }
            }
        }
    });

    // Task: receive commands from the client
    let cmd_runner = runner.clone();
    while let Some(Ok(msg)) = stream.next().await {
        match msg {
            Message::Text(text) => {
                match serde_json::from_str::<SimCommand>(&text) {
                    Ok(cmd) => handle_command(cmd, &cmd_runner),
                    Err(e) => {
                        tracing::warn!("Invalid command: {e}");
                    }
                }
            }
            Message::Close(_) => break,
            _ => {}
        }
    }

    push_task.abort();
}

fn handle_command(cmd: SimCommand, runner: &SimRunner) {
    match cmd {
        SimCommand::Init { num_locations, num_agents } => {
            runner.init(num_locations, num_agents);
        }
        SimCommand::Step => {
            runner.step();
        }
        SimCommand::Play { interval_ms } => {
            let r = runner.clone();
            tokio::spawn(async move {
                let mut ticker = tokio::time::interval(
                    std::time::Duration::from_millis(interval_ms.max(50)),
                );
                loop {
                    ticker.tick().await;
                    if r.tx.receiver_count() == 0 {
                        break;
                    }
                    r.step();
                }
            });
        }
        SimCommand::Pause => {
            // No-op: play tasks will self-terminate when receiver_count drops
            // or when a new Init resets the world.
        }
        SimCommand::UpdateParams(params) => {
            runner.update_params(params);
        }
    }
}
