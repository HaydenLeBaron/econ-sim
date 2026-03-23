use econ_engine::{market::MarketState, sim_params::SimParams, tick, world::World, init};
use econ_shared::{world_to_snapshot, WorldSnapshot};
use std::sync::{Arc, Mutex};
use tokio::sync::watch;

#[derive(Clone)]
pub struct SimState {
    pub world: World,
    pub params: SimParams,
    pub last_market: MarketState,
}

#[derive(Clone)]
pub struct SimRunner {
    pub state: Arc<Mutex<SimState>>,
    pub tx: watch::Sender<Option<WorldSnapshot>>,
    pub rx: watch::Receiver<Option<WorldSnapshot>>,
}

impl SimRunner {
    pub fn new() -> Self {
        let (tx, rx) = watch::channel(None);
        let params = SimParams::default();
        let world = init::generate(50, 20, &params);
        let last_market = MarketState::default();

        let snapshot = world_to_snapshot(&world, &last_market);

        let state = Arc::new(Mutex::new(SimState {
            world,
            params,
            last_market,
        }));

        let _ = tx.send(Some(snapshot));

        SimRunner { state, tx, rx }
    }

    /// Reinitialize the simulation.
    pub fn init(&self, num_locations: usize, num_agents: usize) {
        let mut s = self.state.lock().unwrap();
        s.world = init::generate(num_locations, num_agents, &s.params);
        s.last_market = MarketState::default();
        let snap = world_to_snapshot(&s.world, &s.last_market);
        let _ = self.tx.send(Some(snap));
    }

    /// Advance one tick.
    pub fn step(&self) {
        let mut s = self.state.lock().unwrap();
        let (new_world, market) = tick::tick(s.world.clone(), &s.params);
        s.world = new_world;
        s.last_market = market;
        let snap = world_to_snapshot(&s.world, &s.last_market);
        let _ = self.tx.send(Some(snap));
    }

    /// Update simulation parameters.
    pub fn update_params(&self, params: SimParams) {
        let mut s = self.state.lock().unwrap();
        s.params = params;
    }

    /// Get the current snapshot.
    pub fn snapshot(&self) -> WorldSnapshot {
        let s = self.state.lock().unwrap();
        world_to_snapshot(&s.world, &s.last_market)
    }
}
