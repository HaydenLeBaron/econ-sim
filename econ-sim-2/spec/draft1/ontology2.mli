(**
This Literate Programming document serves as a semi-formal specification for describing an
agent-based simulation of a basic economy (Agent-Based Computational Economics). 

This will be used as a prompt to an LLM which will create a more robust specification (which need not be in OCaml, even though this one is)*)

(*<PROSE>
  Suppose we have an implementation of some Directed Graph. The actual implementation must support:
  - Vertices that contain internal "state" (to be updated functionally). State should be an arbitrary Product Type (Record).
  - Edges that have weights. Weights should be multi-dimensional, also supporting an arbitrary Product Type (Record).
  - The DiGraph should use an adjacently list implementation.
  )
  </PROSE> *)
module DiGraph : sig
  type t
end

(** A World is a DiGraph at a particular point in time, `turnNum`. 

## Vertices

Each Vertex represents a location in the world. A location may contain some number of agents or resources, which will be described more later.

## Edges

Each Edge represents a connection between two locations. The "weights" (implemented as records) of the path between vertices will be used
to represent "costs" or "gates" for agents to travel between locations. Here are some examples of potential representational use cases for edge weights:
- time (number of turns) it takes to travel along this path
- minimum gold required to travel on this path
- hunger/pain inflicted when traveling on this path
- min/max hunger bounds required to travel on this path
- gold subtracted when traveling on this path
- whether it's possible to see the vertex on the other side of this edge
*)

(** The world represents "reality". *)
module World : sig
  type t = { graph : DiGraph.t; turnNum : int }

  (** TODO: specify module more. 
  Vertices can have AgentFood and AgentGold on them 
  (which are perceptible by Agents--to be explained later--as things that they value on account of their hunger and greed.) 
  *)
end

(** An Agent is an economic individual in the world with causal powers (abilities). We will get to what those abilities are. *)
module Agent : sig
  (** An Agent is identified by a unique ID. *)
  module Id : sig
    type t
  end

  (** An Agent also has a state (to be updated functionally). *)
  module State : sig
    (** A WorldModel represents the Agent's own view of the world.*)
    module WorldModel : sig
      type t = DiGraph.t
      (** Agents structure their view of the world as a DiGraph too. *)

      (** Agents construct a world model via their perceptual faculties. *)
      module Perception : sig
        val seeWorld : Id.t -> World.t -> t
        (** When an agent of Id.t sees the world World.t, it constructs a world model t, 
        which is a lossy projection of the real world.

        For example, an agent may or may not be able to see all of the costs to travel between vertices, 
        and some entities in a vertex may be invisible to him. Some of those invisible entities and costs
        may still be able to affect him.
        *)
      end
    end

    (** Agents have a model of themselves too, which is updated by their actions. *)
    module SelfModel : sig
      module Hunger : sig
        type t = { currHunger : float; maxHunger : float }
        (** Agents get hungry when they don't eat food. *)

        (* Agents will die from hunger when `currHunger` > `maxHunger`. *)
      end

      (** Agents also have greed, which is a simple bias towards gold to give it abstract utility in an Agent's utility function, even though
      gold can't really be "used" for anything by agents. *)
      module Greed : sig
        type t = float
      end

      type t = { hunger : Hunger.t; greed : Greed.t }
    end

    (** Agents can carry unlimited food and gold. *)
    module Inventory : sig
      type t = { numFood : float; numGold : float }
    end

    type t = {
      bornOnTurn : int option;
      diedOnTurn : int option;
      selfModel : SelfModel.t;
      worldModel : WorldModel.t;
    }
  end

  (** This module describes everything the Agent can _do_.*)
  module Abilities : sig
    module WorldAgentUpdate : sig
      type t = { newAgentState : State.t; newWorldState : World.t }
      (** Represents a functional update to an Agent and the World*)
    end

    val see : Id.t -> World.t -> State.WorldModel.t
    (** An Agent of Id.t sees the World.t which produces a WorldModel.t which will be used to update the Agent's current world model*)

    val exploit : State.WorldModel.t -> World.t -> WorldAgentUpdate.t
    (** An agent acts from its model of the world State.WorldModel.t and acts on the World.t
    to update itself and the world in a WorldAgentUpdate.t *)

    val explore : State.WorldModel.t -> World.t -> WorldAgentUpdate.t
  end

  type t = { id : Id.t; state : State.t }
end

(*

For each vertex v:
  For each agent a in v:
    a.state <- a.abilities.see a.id World.t
    
    

*)
