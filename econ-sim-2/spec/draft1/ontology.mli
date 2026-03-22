(** 
This file contains a description of the kinds of things that exist in this world.
*)

(* plant people take in sunlight (income/money) and convert it between two goods -- constrained optimization.
   everyone has different utility functions *)

(*
- Consumers (plants, because their income is sunlight) want the bundle of goods that makes them as well off as possible subject to their budget constraints.
- Producers want to maximize their profits.
*)

module DiGraph : sig
  type t
end

(** The world knows where the agent is **)
module World : sig
  type t = { graph : DiGraph.t; turnNum : int }
end

module Helpers : sig end

(** The Agent doesn't know where it is in the world. The world knows. *)
module Agent : sig
  module Id : sig
    type t
  end

  type t

  module State : sig
    module WorldModel : sig
      type t = World.t
      (** An agent's world model is the subset of the World Graph they can see at any given moment *)
    end

    module Hunger : sig
      type t = { currHunger : float; maxHunger : float }
      (** If currHunger exceeds maxHunger, this agent dies. *)
    end

    module Greed : sig
      type t = float
    end

    module Inventory : sig
      type t = { numFood : float; numGold : float }
    end

    type t = {
      bornOnTurn : int;
          (** Hunger varies throughout time, but is constant on any given turn*)
      hunger : Hunger.t;  (** Greed should be static throughout time*)
      greed : Greed.t;
      worldModel : WorldModel.t;
    }
  end

  (** Personality is determined at birth. It is static through time, and only will have 
  aesthetic impact on the world when you talk to an agent *)
  module Personality : sig
    type eiT = Extrovert | Introvert
    type snT = Sensing | Intuitive
    type tfT = Thinking | Feeling
    type pjT = Judging | Perceiving
    type t = { eiT : eiT; snT : snT; tfT : tfT; pjT : pjT }
  end

  (** This module describes everything the Agent can _do_.*)
  module Abilities : sig
    module WorldAgentUpdate : sig
      type t = { newAgentState : State.t; newWorldState : World.t }
      (** Represents a functional update to an Agent and the World*)
    end

    val see : Id.t -> World.t -> State.WorldModel.t
    (** An Agent of Id.t sees the World.t which produces a WorldModel.t*)

    val exploit : State.WorldModel.t -> World.t -> WorldAgentUpdate.t
    (** An agent acts from its model of the world State.WorldModel.t and acts on the World.t
    to update itself and the world in a WorldAgentUpdate.t *)

    val explore : State.WorldModel.t -> World.t -> WorldAgentUpdate.t
  end
end

(* *)

(*
   module Commodities : sig
     module Materia : sig
       type t
     end

     module Energia : sig
       type t
     end
   end

   module EconomicAgent : sig
     type t

     val utilityFn : t -> 'a -> 'b -> int
   end

   module BipartiteHomunculus : sig
     module Spirit : sig
       type t
     end

     module Body : sig
       type t
     end

     module Needs : sig
       type t = { materiaHunger : int; energiaHunger : int }
     end

     (** What can be carried*)
     module Inventory : sig
       type t = { numMateria : int; numEnergia : int }
       (** Can carry infinitely many Materia and Energia. *)
     end

     type t = { body : Body.t; spirit : Spirit.t }
   end

   (** A Homunculus (little man) is a simplistic, independent economic agent that exists within the world to satisfy its
   needs, desires, and aims. *)
   module TripartiteHomunculus : sig
     (** The Soul (Psyche) is tri-partite (3 components), as per Plato. *)
     module Soul : sig
       (** The Rational (Logisitkon) part of the soul. Satisfied by: Truth, knowledge, wisdom, and understanding. *)
       module Rational : sig
         type t
       end

       (** The Spirited (Thymoeides) part of the soul. Satisfied by: Honor, victory, reputation, recognition, and courage. *)
       module Spirited : sig
         type t
       end

       (** The Appetitive (Epithymetikon) part of the soul. Satisfied by: Physical pleasures, bodily comfort, wealth, and material satisfaction *)
       module Appetitive : sig
         type t
       end

       (** The magnitude (size) of the soul *)
       type magnitude = Hi | Med | Lo

       (** Ratios of the parts (components) of the soul *)
       type direction =
         | R67_S33_A33
         | R33_S67_A33
         | R33_S33_A67
         | R80_S10_A10
         | R10_S80_A10
         | R10_S10_A80

       type t = { magnitude : magnitude; direction : direction }

       val tToVec : t -> float * float * float
       (** Converts a soul to a vector of floats (Rational, Spirited, Appetitive) *)
     end

     module Body : sig
       type t
     end

     type t = { soul : Soul.t; body : Body.t }
   end

   (*
   There is a difference between marginal rate of transformation (MRT) and MRS
   *) *)
