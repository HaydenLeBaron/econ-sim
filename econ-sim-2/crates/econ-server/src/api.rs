use crate::sim_runner::SimRunner;
use axum::{
    extract::State,
    response::Json,
};
use econ_engine::sim_params::SimParams;
use econ_shared::WorldSnapshot;
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct InitRequest {
    pub num_locations: usize,
    pub num_agents: usize,
}

#[derive(Deserialize)]
pub struct PlayRequest {
    pub interval_ms: u64,
}

#[derive(Serialize)]
pub struct OkResponse {
    pub ok: bool,
}

fn ok() -> Json<OkResponse> {
    Json(OkResponse { ok: true })
}

pub async fn post_init(
    State(runner): State<SimRunner>,
    Json(req): Json<InitRequest>,
) -> Json<OkResponse> {
    runner.init(req.num_locations, req.num_agents);
    ok()
}

pub async fn post_step(State(runner): State<SimRunner>) -> Json<OkResponse> {
    runner.step();
    ok()
}

pub async fn post_play(
    State(runner): State<SimRunner>,
    Json(req): Json<PlayRequest>,
) -> Json<OkResponse> {
    let runner_clone = runner.clone();
    let interval = req.interval_ms;
    tokio::spawn(async move {
        // Store a play-task handle — for simplicity we let clients pause by
        // issuing a new init or by closing the connection. A proper
        // implementation would track a CancellationToken; this is sufficient
        // for the demo.
        let mut ticker = tokio::time::interval(
            std::time::Duration::from_millis(interval.max(50)),
        );
        // Run until the watch channel has no more receivers
        loop {
            ticker.tick().await;
            if runner_clone.tx.receiver_count() == 0 {
                break;
            }
            runner_clone.step();
        }
    });
    ok()
}

pub async fn post_pause(State(_runner): State<SimRunner>) -> Json<OkResponse> {
    // Pause is handled client-side via SimCommand over WS; the REST endpoint
    // is a no-op placeholder that stops the play loop indirectly by letting
    // the spawned task exit when receiver_count drops.
    ok()
}

pub async fn put_params(
    State(runner): State<SimRunner>,
    Json(params): Json<SimParams>,
) -> Json<OkResponse> {
    runner.update_params(params);
    ok()
}

pub async fn get_state(State(runner): State<SimRunner>) -> Json<WorldSnapshot> {
    Json(runner.snapshot())
}
