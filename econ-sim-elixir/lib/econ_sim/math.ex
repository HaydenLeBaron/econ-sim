defmodule EconSim.Math do
  @moduledoc """
  Microeconomic math functions: Cobb-Douglas utility, MRS, marginal utilities,
  and indifference curve generation. Direct port of src/engine/math.ts.
  """

  alias EconSim.Types.Agent

  @type preference_params :: %{alpha: float(), beta: float()}

  @doc """
  Derives the Cobb-Douglas scaling parameters from an agent's hunger and greed.
  alpha: weight for food (scales exponentially with hunger)
  beta: weight for gold (scales exponentially with greed)
  Normalized so alpha + beta = 1.
  """
  @spec derive_preference_params(Agent.t()) :: preference_params()
  def derive_preference_params(%Agent{} = agent) do
    raw_alpha = :math.pow(2, agent.curr_hunger)
    raw_beta = :math.pow(2, agent.base_greed) * 0.5
    sum = raw_alpha + raw_beta
    %{alpha: raw_alpha / sum, beta: raw_beta / sum}
  end

  @doc """
  Calculates Marginal Rate of Substitution.
  MRS = (alpha / beta) * ((G + 1) / (F + 1))
  Represents how many gold units the agent values 1 food unit at.
  """
  @spec calculate_mrs(Agent.t()) :: float()
  def calculate_mrs(%Agent{} = agent) do
    %{alpha: alpha, beta: beta} = derive_preference_params(agent)
    (alpha / beta) * ((agent.gold_inventory + 1) / (agent.food_inventory + 1))
  end

  @doc """
  Marginal utility of food.
  MU_F = alpha * (F + 1)^(alpha - 1) * (G + 1)^beta
  """
  @spec calculate_mu_food(Agent.t()) :: float()
  def calculate_mu_food(%Agent{} = agent) do
    %{alpha: alpha, beta: beta} = derive_preference_params(agent)
    f = agent.food_inventory
    g = agent.gold_inventory
    alpha * :math.pow(f + 1, alpha - 1) * :math.pow(g + 1, beta)
  end

  @doc """
  Marginal utility of gold.
  MU_G = beta * (F + 1)^alpha * (G + 1)^(beta - 1)
  """
  @spec calculate_mu_gold(Agent.t()) :: float()
  def calculate_mu_gold(%Agent{} = agent) do
    %{alpha: alpha, beta: beta} = derive_preference_params(agent)
    f = agent.food_inventory
    g = agent.gold_inventory
    beta * :math.pow(f + 1, alpha) * :math.pow(g + 1, beta - 1)
  end

  @doc """
  Calculates total utility of a consumption bundle.
  U(F, G) = (F + 1)^alpha * (G + 1)^beta
  """
  @spec calculate_utility(float(), float(), preference_params()) :: float()
  def calculate_utility(food, gold, %{alpha: alpha, beta: beta}) do
    :math.pow(food + 1, alpha) * :math.pow(gold + 1, beta)
  end

  @doc """
  Generates indifference curve points for the agent's current utility level.
  Returns a list of %{x: food, y: gold} points.
  """
  @spec generate_indifference_curve(Agent.t(), integer()) :: [%{x: float(), y: float()}]
  def generate_indifference_curve(%Agent{} = agent, max_food \\ 20) do
    params = derive_preference_params(agent)
    current_utility = calculate_utility(agent.food_inventory, agent.gold_inventory, params)

    Enum.map(0..max_food, fn f ->
      # G = (U / (F + 1)^alpha)^(1 / beta) - 1
      base = current_utility / :math.pow(f + 1, params.alpha)
      g = :math.pow(base, 1 / params.beta) - 1
      %{x: f, y: max(0.0, g)}
    end)
  end
end
