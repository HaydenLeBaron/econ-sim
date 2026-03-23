use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Opaque vertex identifier — a monotonically increasing u64.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub struct VertexId(pub u64);

static VERTEX_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

impl VertexId {
    pub fn fresh() -> Self {
        VertexId(VERTEX_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed))
    }
}

impl std::fmt::Display for VertexId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "V{}", self.0)
    }
}

/// A polymorphic directed graph with vertex state V and edge weight E.
/// Represented as an adjacency list: vertex_id → (vertex_state, outgoing_edges).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DiGraph<V, E> {
    pub(crate) inner: HashMap<VertexId, (V, HashMap<VertexId, E>)>,
}

impl<V, E> DiGraph<V, E> {
    pub fn empty() -> Self {
        DiGraph { inner: HashMap::new() }
    }

    pub fn vertex_state(&self, id: VertexId) -> Option<&V> {
        self.inner.get(&id).map(|(v, _)| v)
    }

    pub fn vertex_state_mut(&mut self, id: VertexId) -> Option<&mut V> {
        self.inner.get_mut(&id).map(|(v, _)| v)
    }

    pub fn edge_weight(&self, src: VertexId, dst: VertexId) -> Option<&E> {
        self.inner.get(&src)?.1.get(&dst)
    }

    pub fn neighbors(&self, id: VertexId) -> Vec<(VertexId, &E)> {
        match self.inner.get(&id) {
            Some((_, edges)) => edges.iter().map(|(dst, e)| (*dst, e)).collect(),
            None => vec![],
        }
    }

    pub fn vertices(&self) -> Vec<(VertexId, &V)> {
        self.inner.iter().map(|(id, (v, _))| (*id, v)).collect()
    }

    pub fn update_vertex<F>(&mut self, id: VertexId, f: F)
    where
        F: FnOnce(&mut V),
    {
        if let Some((v, _)) = self.inner.get_mut(&id) {
            f(v);
        }
    }

    pub fn update_edge<F>(&mut self, src: VertexId, dst: VertexId, f: F)
    where
        F: FnOnce(&mut E),
    {
        if let Some((_, edges)) = self.inner.get_mut(&src) {
            if let Some(e) = edges.get_mut(&dst) {
                f(e);
            }
        }
    }

    pub fn contains_vertex(&self, id: VertexId) -> bool {
        self.inner.contains_key(&id)
    }

    pub fn vertex_count(&self) -> usize {
        self.inner.len()
    }

    pub fn insert_vertex(&mut self, id: VertexId, state: V) {
        self.inner.insert(id, (state, HashMap::new()));
    }

    pub fn add_edge_mut(&mut self, src: VertexId, dst: VertexId, weight: E) {
        if let Some((_, edges)) = self.inner.get_mut(&src) {
            edges.insert(dst, weight);
        }
    }

    pub fn vertex_ids(&self) -> Vec<VertexId> {
        self.inner.keys().copied().collect()
    }
}
