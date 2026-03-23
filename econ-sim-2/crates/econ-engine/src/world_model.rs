use crate::digraph::DiGraph;
use crate::location::Location;
use crate::path::Path;

/// An agent's subjective, possibly incomplete view of the world.
/// Structured identically to the real world graph but may have
/// fewer vertices, fewer edges, and stale resource data.
pub type WorldModel = DiGraph<Location, Path>;
