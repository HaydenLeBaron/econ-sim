defmodule EconSim.Globals do
  @moduledoc """
  Global simulation constants.
  """

  def max_food_per_block, do: 20
  def food_growth_rate, do: 0.5
  def food_consumption_rate, do: 1
  def hunger_per_turn, do: 0.3
  def death_at_hunger, do: 10
  def max_pregnancy_hunger, do: 4
  def starting_baby_hunger, do: 5
  def birthing_hunger_cost, do: 2.5
  def reproduce_chance, do: 1.0
end
