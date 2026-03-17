import type { Agent } from './types';

export type PreferenceParams = {
  readonly alpha: number;
  readonly beta: number;
};

/**
 * Derives the scaling parameters for the Cobb-Douglas utility function.
 * alpha: Weight for food (needs to scale based on Hunger)
 * beta: Weight for gold (scales based on base Greed)
 */
export const derivePreferenceParams = (agent: Agent): PreferenceParams => {
  // E.g. A hyper-hungry agent sees a massive spike in alpha, overriding beta.
  const alpha = Math.pow(10, agent.currHunger); // Hunger.Hi (2) -> 100, Lo (1) -> 10, None (0) -> 1
  const beta = Math.pow(10, agent.baseGreed) * 0.5; // Scaled so Hunger prevents starvation
  return { alpha, beta };
};

/**
 * Calculates current Marginal Rate of Substitution (MRS) given an agent's state.
 * Represents how many units of Gold the agent values 1 unit of Food at.
 * MRS = - (MU_F / MU_G) = (alpha / beta) * ((G + 1) / (F + 1))
 */
export const calculateMRS = (agent: Agent): number => {
  const { alpha, beta } = derivePreferenceParams(agent);
  const { foodInventory: f, goldInventory: g } = agent;
  
  return (alpha / beta) * ((g + 1) / (f + 1));
};

/**
 * Calculates the total utility of a given consumption bundle
 * U(F, G) = (F + 1)^alpha * (G + 1)^beta
 */
export const calculateUtility = (food: number, gold: number, params: PreferenceParams): number => {
  return Math.pow(food + 1, params.alpha) * Math.pow(gold + 1, params.beta);
};

/**
 * Generates a set of (Food, Gold) points that provide the exact same utility 
 * as the agent's current inventory. These are used to plot the indifference curve.
 */
export const generateIndifferenceCurve = (agent: Agent, maxFood: number = 20): Array<{x: number, y: number}> => {
  const params = derivePreferenceParams(agent);
  const currentUtility = calculateUtility(agent.foodInventory, agent.goldInventory, params);
  const curve = [];

  for (let f = 0; f <= maxFood; f++) {
    // Math derivation:
    // U = (F + 1)^alpha * (G + 1)^beta
    // (G + 1)^beta = U / (F + 1)^alpha
    // G + 1 = (U / (F + 1)^alpha)^(1 / beta)
    // G = (U / (F + 1)^alpha)^(1 / beta) - 1
    
    // We max(0, g) to prevent negative gold points in the plot 
    const base = currentUtility / Math.pow(f + 1, params.alpha);
    const g = Math.pow(base, 1 / params.beta) - 1;
    curve.push({ x: f, y: Math.max(0, g) });
  }

  return curve;
};
