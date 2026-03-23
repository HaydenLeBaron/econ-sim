mod api;
mod sim_runner;
mod ws;

use axum::{
    routing::{get, post, put},
    Router,
};
use sim_runner::SimRunner;
use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("info".parse().unwrap()))
        .init();

    let runner = SimRunner::new();

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = Router::new()
        .route("/api/sim", post(api::post_init))
        .route("/api/sim/step", post(api::post_step))
        .route("/api/sim/play", post(api::post_play))
        .route("/api/sim/pause", post(api::post_pause))
        .route("/api/sim/params", put(api::put_params))
        .route("/api/sim/state", get(api::get_state))
        .route("/ws", get(ws::ws_handler))
        .with_state(runner)
        .layer(cors);

    let addr = "0.0.0.0:3000";
    tracing::info!("Listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
