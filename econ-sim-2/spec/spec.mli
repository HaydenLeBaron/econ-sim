(** {1 Econ-Sim-2: Agent-Based Computational Economics}

    This document is a semi-formal specification for an agent-based simulation
    of a basic economy. Agents inhabit a directed graph of locations, gather
    resources, make decisions under bounded rationality, trade on a market, and
    reproduce. The simulation proceeds in discrete turns.

    {b Notation.} All state updates are functional: functions return new values
    rather than mutating existing ones. Types marked [abstract] in this spec
    must be provided by the implementation but their representation is
    unspecified here. *)

(* ================================================================ *)
(** {2 Directed Graph} *)
(* ================================================================ *)

(** A polymorphic directed graph with labeled vertices and weighted edges.
    Implemented as an adjacency list keyed by vertex id. *)
module DiGraph : sig
  (** Abstract vertex identifier. Must be comparable and hashable. *)
  module VertexId : sig
    type t
    val equal : t -> t -> bool
    val compare : t -> t -> int
  end

  (** A directed graph parameterised over vertex state ['v] and edge
      weight ['e]. *)
  type ('v, 'e) t

  (** {3 Construction} *)

  val empty : ('v, 'e) t
  val add_vertex : VertexId.t -> 'v -> ('v, 'e) t -> ('v, 'e) t
  val add_edge : src:VertexId.t -> dst:VertexId.t -> 'e -> ('v, 'e) t -> ('v, 'e) t

  (** {3 Query} *)

  val vertex_state : VertexId.t -> ('v, 'e) t -> 'v option
  val edge_weight : src:VertexId.t -> dst:VertexId.t -> ('v, 'e) t -> 'e option
  val neighbors : VertexId.t -> ('v, 'e) t -> (VertexId.t * 'e) list
  val vertices : ('v, 'e) t -> (VertexId.t * 'v) list

  (** {3 Update} *)

  val update_vertex : VertexId.t -> ('v -> 'v) -> ('v, 'e) t -> ('v, 'e) t
  (** [update_vertex vid f g] applies [f] to the state of vertex [vid] in [g].
      No-op if [vid] is absent. *)

  val update_edge : src:VertexId.t -> dst:VertexId.t -> ('e -> 'e) -> ('v, 'e) t -> ('v, 'e) t
end

(* ================================================================ *)
(** {2 Resources} *)
(* ================================================================ *)

(** The two tangible resources in the economy. *)
module Resource : sig
  type kind = Food | Gold

  (** A bundle of resources an entity can hold. *)
  type bundle = {
    food : float;  (** non-negative *)
    gold : float;  (** non-negative *)
  }

  val zero : bundle
  val add : bundle -> bundle -> bundle
  val scale : float -> bundle -> bundle
end

(* ================================================================ *)
(** {2 Location (Vertex State)} *)
(* ================================================================ *)

(** Each vertex in the world graph is a {i location} that has a terrain type,
    resource deposits, and a set of occupying agents. *)
module Location : sig
  (** Terrain determines what resource, if any, naturally regenerates here. *)
  type terrain =
    | Dirt   (** No natural regeneration; reproduction can occur here. *)
    | Farm   (** Food regenerates each turn up to a cap. *)
    | Mine   (** Gold regenerates each turn up to a cap. *)

  type t = {
    terrain : terrain;
    resources : Resource.bundle;
    (** Harvestable resources currently available at this location.
        Capped per-resource by [SimParams.max_resource_per_location]. *)
    agent_ids : AgentId.t list;
    (** Agents currently occupying this location. Order is irrelevant;
        resource distribution among co-located agents is always fair
        (equal shares). *)
  }
end

(* ================================================================ *)
(** {2 Path (Edge Weight)} *)
(* ================================================================ *)

(** Edge weights encode the cost and prerequisites for traveling from one
    location to another. Every field is optional in the sense that a default
    (zero-cost, no gate) value means "no constraint". *)
module Path : sig
  type t = {
    travel_time : int;
    (** Number of turns consumed by traversal. Minimum 1. *)
    gold_cost : float;
    (** Gold subtracted from the agent upon traversal. Must have at least
        this much gold to enter. *)
    hunger_cost : float;
    (** Hunger added to the agent upon traversal. *)
    min_hunger : float;
    (** Agent's [currHunger] must be >= this to enter. *)
    max_hunger : float;
    (** Agent's [currHunger] must be <= this to enter. *)
    visible : bool;
    (** Whether agents at the source can perceive the destination vertex
        through this edge. If [false], the destination is hidden from
        perception but the edge still exists in reality. *)
  }

  val default : t
  (** [{travel_time=1; gold_cost=0.; hunger_cost=0.; min_hunger=0.;
        max_hunger=infinity; visible=true}] *)
end

(* ================================================================ *)
(** {2 Agent Identity} *)
(* ================================================================ *)

module AgentId : sig
  type t
  val equal : t -> t -> bool
  val fresh : unit -> t
  (** Generate a globally unique agent identifier. *)
end

(* ================================================================ *)
(** {2 Agent Self-Model} *)
(* ================================================================ *)

(** The agent's knowledge of its own internal state. *)
module SelfModel : sig
  module Hunger : sig
    type t = {
      current : float;
      (** Increases by [SimParams.hunger_per_turn] each turn the agent does
          not eat. Decreased by eating food (1 food reduces hunger by 1).
          Clamped to [0, max]. *)
      max : float;
      (** When [current > max], the agent dies of starvation. *)
    }
  end

  module Greed : sig
    type t = float
    (** A non-negative bias towards gold. Enters the utility function to give
        gold abstract value even though gold has no direct consumptive use. *)
  end

  type t = {
    hunger : Hunger.t;
    greed : Greed.t;
  }
end

(* ================================================================ *)
(** {2 Agent Inventory} *)
(* ================================================================ *)

module Inventory : sig
  type t = Resource.bundle
  (** Agents can carry unlimited food and gold. *)
end

(* ================================================================ *)
(** {2 Utility and Preferences} *)
(* ================================================================ *)

(** Agents evaluate outcomes using a Cobb-Douglas utility function with
    preference parameters derived from their current hunger and greed. *)
module Utility : sig
  type params = {
    alpha : float;  (** weight on food, in (0,1) *)
    beta : float;   (** weight on gold, in (0,1); alpha + beta = 1 *)
  }

  val derive_params : SelfModel.t -> params
  (** Compute preference parameters from the agent's self-model.
      {[
        raw_alpha = 2 ^ current_hunger
        raw_beta  = 2 ^ greed * 0.5
        alpha     = raw_alpha / (raw_alpha + raw_beta)
        beta      = raw_beta  / (raw_alpha + raw_beta)
      ]}
      Hunger creates urgency for food; greed creates desire for gold.
      Normalization ensures [alpha + beta = 1]. *)

  val utility : food:float -> gold:float -> params -> float
  (** [utility ~food ~gold p = (food + 1)^p.alpha * (gold + 1)^p.beta]

      The [+1] offset ensures the function is defined and positive even when
      a resource quantity is zero. *)

  val marginal_utility_food : food:float -> gold:float -> params -> float
  (** [dU/dF = alpha * (food+1)^(alpha-1) * (gold+1)^beta] *)

  val marginal_utility_gold : food:float -> gold:float -> params -> float
  (** [dU/dG = (food+1)^alpha * beta * (gold+1)^(beta-1)] *)

  val mrs : food:float -> gold:float -> params -> float
  (** Marginal Rate of Substitution (gold per food):
      [MRS = (alpha / beta) * ((gold + 1) / (food + 1))]

      Interpretation: the amount of gold the agent is willing to give up
      for one additional unit of food, at the margin. *)
end

(* ================================================================ *)
(** {2 Agent World Model (Perception)} *)
(* ================================================================ *)

(** An agent's subjective, possibly incomplete view of the world.
    Structured as a DiGraph with the same type parameters as the real world
    but potentially fewer vertices, edges, and less accurate state. *)
module WorldModel : sig
  type t = (Location.t, Path.t) DiGraph.t
  (** A lossy projection of the true world graph. Some vertices may be
      missing (unseen locations), some edge weights may be defaults
      (unknown costs), and resource quantities may be stale or absent. *)
end

(* ================================================================ *)
(** {2 Perception} *)
(* ================================================================ *)

(** How agents construct their world model from reality. *)
module Perception : sig
  val see : AgentId.t -> World.t -> WorldModel.t
  (** [see aid world] constructs agent [aid]'s subjective world model.

      {b Visibility rules:}
      - The agent always perceives the vertex it currently occupies, including
        all resources and other agents present.
      - For each outgoing edge from the agent's current vertex:
        - If [edge.visible = true], the agent perceives the destination
          vertex (with its terrain and resources) and the edge weight.
        - If [edge.visible = false], neither the destination vertex nor the
          edge appears in the world model.
      - Vertices and edges beyond one hop are {i not} perceived (no
        transitive visibility). An agent can only see its immediate
        neighborhood.
      - An agent cannot perceive other agents' internal states (hunger,
        greed, inventory). It can only see that other agents exist at a
        location. *)
end

(* ================================================================ *)
(** {2 Agent (Complete)} *)
(* ================================================================ *)

module Agent : sig
  type t = {
    id : AgentId.t;
    born_on_turn : int;
    died_on_turn : int option;
    (** [None] while alive; [Some t] once dead. Dead agents are retained
        in the simulation state for historical record but take no actions. *)
    self_model : SelfModel.t;
    world_model : WorldModel.t;
    inventory : Inventory.t;
    location : DiGraph.VertexId.t;
    (** The vertex the agent currently occupies. *)
  }

  val is_alive : t -> bool
  (** [died_on_turn = None] *)
end

(* ================================================================ *)
(** {2 World} *)
(* ================================================================ *)

(** The world represents objective reality: the graph of locations plus all
    agents (living and dead) and the current turn number. *)
module World : sig
  type t = {
    graph : (Location.t, Path.t) DiGraph.t;
    agents : Agent.t list;
    (** All agents that have ever existed. Dead agents are retained. *)
    turn : int;
  }
end

(* ================================================================ *)
(** {2 Agent Decisions} *)
(* ================================================================ *)

(** Each turn, an agent chooses exactly one action. The choice is based on
    expected utility maximization given the agent's world model. *)
module Decision : sig
  type action =
    | Exploit
    (** Stay at the current location and harvest resources.
        The agent's expected resource gain from exploiting is computed as
        a fair share of the location's visible resources:
        {[
          expected_food = location.resources.food / num_agents_here
          expected_gold = location.resources.gold / num_agents_here
        ]} *)
    | Explore of DiGraph.VertexId.t
    (** Move to an adjacent vertex (if the agent satisfies the edge's
        gate predicates). The agent's expected resource gain from exploring
        is a fixed optimistic estimate:
        {[
          expected_food = SimParams.explore_expected_food
          expected_gold = SimParams.explore_expected_gold
        ]} *)

  val decide : Agent.t -> action
  (** Compare the expected utility after exploiting vs. exploring each
      reachable neighbor, and return the action with highest expected
      utility. Ties are broken in favor of Exploit. *)
end

(* ================================================================ *)
(** {2 Market} *)
(* ================================================================ *)

(** A global double-auction market where agents trade food for gold.
    The market runs once per turn {i after} all agent actions have resolved. *)
module Market : sig
  type order = {
    agent_id : AgentId.t;
    price : float;
    (** In gold-per-food units. *)
    quantity : float;
    (** Units of food to buy or sell. *)
  }

  type side = Bid | Ask

  type trade = {
    buyer : AgentId.t;
    seller : AgentId.t;
    price : float;
    (** Execution price = (bid_price + ask_price) / 2. *)
    quantity : float;
    turn : int;
  }

  type state = {
    bids : order list;
    asks : order list;
    clearing_price : float option;
    (** Price of the last matched trade this turn, if any. *)
    volume : float;
    (** Total food units traded this turn. *)
    history : trade list;
    (** All trades executed this turn. *)
  }

  val generate_orders : Agent.t list -> (order * side) list
  (** For each living agent:
      - Compute its MRS.
      - If [MRS > 1.0]: the agent values food more than gold at the margin,
        so it submits a {b Bid} to buy food at price up to MRS, quantity 1.
      - If [MRS < 1.0]: the agent values gold more than food at the margin,
        so it submits an {b Ask} to sell food at price at least MRS, quantity 1.
      - If [MRS = 1.0]: the agent is indifferent and does not trade. *)

  val resolve : (order * side) list -> Agent.t list -> turn:int -> state * Agent.t list
  (** Match bids against asks:
      1. Sort bids descending by price, asks ascending by price.
      2. While the highest remaining bid >= the lowest remaining ask:
         a. Match them. Execution price = (bid + ask) / 2.
         b. Transfer food from seller to buyer, gold from buyer to seller.
         c. Record the trade.
      3. Return updated market state and agents with adjusted inventories. *)
end

(* ================================================================ *)
(** {2 Simulation Parameters} *)
(* ================================================================ *)

(** Global constants governing simulation dynamics. All values below are
    defaults; an implementation may allow overrides at initialization. *)
module SimParams : sig
  val hunger_per_turn : float
  (** Hunger added per turn when the agent does not eat. Default: 0.3 *)

  val max_hunger_default : float
  (** Default max hunger threshold for new agents. Default: 10.0 *)

  val food_regen_per_turn : float
  (** Food added per turn to Farm locations. Default: 1.0 *)

  val gold_regen_per_turn : float
  (** Gold added per turn to Mine locations. Default: 1.0 *)

  val max_resource_per_location : float
  (** Cap on each resource type at a single location. Default: 10.0 *)

  val gold_harvest_limit_per_agent : float
  (** Maximum gold a single agent can harvest per turn on a Mine. Default: 1.0 *)

  val explore_expected_food : float
  (** Optimistic food expectation when choosing Explore. Default: 0.5 *)

  val explore_expected_gold : float
  (** Optimistic gold expectation when choosing Explore. Default: 0.1 *)

  val fertility_threshold : int
  (** Minimum number of living agents co-located on a Dirt tile for
      reproduction to occur. Default: 2 *)

  val market_enabled : bool
  (** Whether the market runs each turn. Default: true *)
end

(* ================================================================ *)
(** {2 Simulation Loop} *)
(* ================================================================ *)

(** One tick of the simulation advances the world by one turn. *)
module Tick : sig
  val tick : World.t -> World.t
  (** [tick world] produces the next world state. The phases execute in
      strict sequential order:

      {b Phase 1: Environment Regeneration.}
      For each location in the graph:
      - If terrain = Farm: [resources.food <- min(resources.food + food_regen_per_turn, max_resource_per_location)]
      - If terrain = Mine: [resources.gold <- min(resources.gold + gold_regen_per_turn, max_resource_per_location)]
      - Dirt locations do not regenerate.

      {b Phase 2: Perception.}
      For each living agent [a]:
      - [a.world_model <- Perception.see a.id world]

      {b Phase 3: Decision.}
      For each living agent [a]:
      - [a.action <- Decision.decide a]

      {b Phase 4: Action Resolution.}
      Process agents grouped by their current location.
      For each location [v] and its occupants:

      {i Exploiters} (agents choosing Exploit on [v]):
      - Divide [v.resources] equally among all exploiters.
        Each receives [v.resources / n_exploiters] (fair share).
      - Subtract distributed resources from [v.resources].
      - Add harvested resources to each agent's inventory.
        Gold harvesting is capped at [gold_harvest_limit_per_agent] per agent.

      {i Explorers} (agents choosing Explore to an adjacent vertex):
      - Verify the agent satisfies the edge's gate predicates:
        - [agent.inventory.gold >= edge.gold_cost]
        - [edge.min_hunger <= agent.self_model.hunger.current <= edge.max_hunger]
      - If satisfied: deduct [edge.gold_cost] from inventory, add
        [edge.hunger_cost] to hunger, move agent to the destination vertex.
      - If not satisfied: the agent stays (wasted turn).

      {b Phase 5: Consumption and Hunger.}
      For each living agent [a]:
      - The agent eats as much food from inventory as needed to reduce
        hunger, at a rate of 1 food per 1 hunger:
        {[
          food_to_eat   = min(a.inventory.food, a.self_model.hunger.current)
          a.inventory.food   <- a.inventory.food   - food_to_eat
          a.self_model.hunger.current <- a.self_model.hunger.current - food_to_eat
        ]}
      - If the agent still has [hunger.current > 0] after eating,
        hunger increases by [hunger_per_turn]:
        {[
          a.self_model.hunger.current <- a.self_model.hunger.current + hunger_per_turn
        ]}

      {b Phase 6: Death.}
      For each living agent [a]:
      - If [a.self_model.hunger.current > a.self_model.hunger.max]:
        - [a.died_on_turn <- Some world.turn]
        - Drop all gold in [a.inventory] onto the agent's current location:
          [location.resources.gold <- location.resources.gold + a.inventory.gold]
        - [a.inventory <- Resource.zero]

      {b Phase 7: Reproduction.}
      For each Dirt location [v]:
      - Let [fertile] = living agents at [v] whose
        [inventory.food >= 1.0].
      - If [|fertile| >= fertility_threshold]:
        - Spawn a new agent at [v] with:
          - A fresh [AgentId]
          - [born_on_turn = world.turn]
          - [hunger = \{ current = 0; max = max_hunger_default \}]
          - [greed] = mean of parents' greed values
          - [inventory = Resource.zero]
        - Each fertile parent pays 0.5 food.

      {b Phase 8: Market.}
      If [market_enabled]:
      - [orders <- Market.generate_orders (living agents)]
      - [(market_state, agents') <- Market.resolve orders agents ~turn:world.turn]

      {b Phase 9: Advance Turn.}
      - [world.turn <- world.turn + 1]
  *)
end

(* ================================================================ *)
(** {2 Initialization} *)
(* ================================================================ *)

module Init : sig
  val generate : width:int -> height:int -> num_agents:int -> World.t
  (** Create an initial world state.

      {b Graph construction.}
      - Create a [width * height] grid of vertices.
      - Assign terrain randomly: ~75% Dirt, ~20% Farm, ~5% Mine.
      - Connect each vertex to its 4 cardinal neighbors (if they exist)
        with [Path.default] edge weights. The graph is directed; both
        directions are added, so edges are effectively bidirectional.

      {b Agent placement.}
      - Create [num_agents] agents at random locations.
      - Each agent starts with:
        - [hunger = \{ current = 0.0; max = max_hunger_default \}]
        - [greed] = random float in [0.0, 2.0]
        - [inventory = Resource.zero]
        - [born_on_turn = 0]
        - [world_model = empty graph]

      {b Turn.}
      - [turn = 0]. *)
end
