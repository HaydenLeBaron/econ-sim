import { GLOBALS, type WorldState, type Agent, type Position } from './types';
import { calculateUtility, derivePreferenceParams } from './math';

/**
 * Increments food on green squares by 1 (up to MAX_FOOD_PER_BLOCK).
 * Gold squares remain unchanged.
 */
export const updateEnvironment = (grid: WorldState['grid']): WorldState['grid'] => {
  return grid.map(row => 
    row.map(sq => {
      if (sq.type === 'Food') {
        return {
          ...sq,
          foodResources: Math.min(GLOBALS.MAX_FOOD_PER_BLOCK, sq.foodResources + GLOBALS.FOOD_GROWTH_RATE)
        };
      }
      return sq;
    })
  );
};

const getAdjacentPositions = (pos: Position, gridWidth: number, gridHeight: number): Position[] => {
  const adjs: Position[] = [];
  if (pos.x > 0) adjs.push({ x: pos.x - 1, y: pos.y });
  if (pos.x < gridWidth - 1) adjs.push({ x: pos.x + 1, y: pos.y });
  if (pos.y > 0) adjs.push({ x: pos.x, y: pos.y - 1 });
  if (pos.y < gridHeight - 1) adjs.push({ x: pos.x, y: pos.y + 1 });
  return adjs;
};

type ActionResolution = {
  agent: Agent;
  foodDelta: number;
  goldDelta: number;
};

/**
 * Decides whether an agent should Exploit (harvest) or Explore (move).
 * Calculates expected utility of actions based on preference parameters.
 */
export const resolveAgentAction = (agent: Agent, grid: WorldState['grid']): ActionResolution => {
  const sq = grid[agent.pos.y] && grid[agent.pos.y][agent.pos.x]; // Safe navigation just in case
  if (!sq) {
    // Should never happen, but returning dummy to satisfy compiler
    return { agent, foodDelta: 0, goldDelta: 0 };
  }
  const params = derivePreferenceParams(agent);
  
  const currentUtility = calculateUtility(agent.foodInventory, agent.goldInventory, params);
  
  let dF = 0;
  let dG = 0;
  
  if (sq.type === 'Food' && sq.foodResources > 0) {
    dF = sq.foodResources;
  } else if (sq.type === 'Gold' && sq.goldResources > 0) {
    dG = 1; // Mine 1 gold
  }
  
  const exploitUtility = calculateUtility(agent.foodInventory + dF, agent.goldInventory + dG, params);
  
  // Calculate expected utility of exploring.
  // We approximate this by assuming there's a chance to find Gold or Food if they move.
  // In a real model, this would be computed over the adjacent squares' actual contents,
  // but for greed/hunger to work broadly, we can assign a baseline expected delta.
  const expectedExploreDeltas = { dF: 0.5, dG: 0.1 }; // small expected find
  const exploreUtility = calculateUtility(agent.foodInventory + expectedExploreDeltas.dF, agent.goldInventory + expectedExploreDeltas.dG, params);
  
  // They only exploit if the *marginal* bump from exploiting exceeds the *marginal* bump from exploring
  const exploitMarginal = exploitUtility - currentUtility;
  const exploreMarginal = exploreUtility - currentUtility;
  
  if (exploitMarginal > exploreMarginal && exploitMarginal > 0) {
    // EXPLOIT
    let newHunger = agent.currHunger;
    let storedFood = agent.foodInventory + dF;
    
    // Satisfy hunger if we got food
    if (dF > 0) {
      while (newHunger > 0 && storedFood >= GLOBALS.FOOD_CONSUMPTION_RATE) {
        storedFood -= GLOBALS.FOOD_CONSUMPTION_RATE;
        newHunger = Math.max(0, newHunger - GLOBALS.FOOD_CONSUMPTION_RATE);
      }
    }

    return {
      agent: {
        ...agent,
        currHunger: newHunger,
        foodInventory: storedFood,
        goldInventory: agent.goldInventory + dG
      },
      foodDelta: -dF,
      goldDelta: -dG // Deplete the resource!
    };
  } else {
    // EXPLORE
    const adjs = getAdjacentPositions(agent.pos, grid[0].length, grid.length);
    const randomAdj = adjs[Math.floor(Math.random() * adjs.length)];

    return {
      agent: {
        ...agent,
        pos: randomAdj,
      },
      foodDelta: 0,
      goldDelta: 0
    };
  }
};

/**
 * Pure reducer function mapping WorldState to exactly the next WorldState.
 */
export const tick = (prevState: WorldState): WorldState => {
  // First, Environment naturally updates (food grows)
  let nextGrid = updateEnvironment(prevState.grid).map(row => [...row]);
  
  // Then Agents take turns
  const nextAgents = prevState.agents.map(agent => {
    // Dead agents take no action
    if (agent.isDead) return agent;
    // Because this resolves independently against the PREVIOUS state grid,
    // agents might magically harvest the same food in one turn if they share a tile.
    // For a simple model, we'll allow it (or we would reduce them sequentially, but PRD implies map).
    const resolution = resolveAgentAction(agent, prevState.grid);
    
    // Apply grid updates from agent actions
    if (resolution.foodDelta !== 0 || resolution.goldDelta !== 0) {
      const sq = nextGrid[resolution.agent.pos.y][resolution.agent.pos.x];
      nextGrid[resolution.agent.pos.y][resolution.agent.pos.x] = {
        ...sq,
        foodResources: Math.max(0, sq.foodResources + resolution.foodDelta),
        goldResources: Math.max(0, sq.goldResources + resolution.goldDelta),
      };
    }
    
    // Apply per-tick rule: Consume 1 food OR increment hunger
    let finalFood = resolution.agent.foodInventory;
    let finalHunger = resolution.agent.currHunger;
    
    if (finalFood >= GLOBALS.FOOD_CONSUMPTION_RATE) {
      finalFood -= GLOBALS.FOOD_CONSUMPTION_RATE;
      // Depending on rules, eating food might decrease hunger too? User said: consume 1 food OR increment hunger.
      // So if they have food, they consume it and hunger doesn't go up. (If they want it to go down, we do that here).
      // If we keep our rule that eating food lowers hunger:
      finalHunger = Math.max(0, finalHunger - 1);
    } else {
      // No food to eat!
      finalHunger += GLOBALS.HUNGER_ACCUMULATED_PER_TURN;
    }
    
    // Check death
    const shouldDie = finalHunger >= GLOBALS.DEATH_AT_HUNGER;
    
    return {
      ...resolution.agent,
      foodInventory: finalFood,
      currHunger: finalHunger,
      isDead: shouldDie,
      diedAtTick: shouldDie ? prevState.tick + 1 : undefined,
    };
  });
  
  return {
    tick: prevState.tick + 1,
    grid: nextGrid,
    agents: nextAgents // New agent states including movements and updated inventories
  };
};
