import { Hunger, GLOBALS, type WorldState, type Agent, type Position } from './types';
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
  const sq = grid[agent.pos.y][agent.pos.x];
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
  
  if (exploitUtility > currentUtility) {
    // EXPLOIT
    let newHunger = agent.currHunger;
    let storedFood = agent.foodInventory + dF;
    
    // Satisfy hunger if we got food
    if (dF > 0) {
      while (newHunger > Hunger.None && storedFood >= GLOBALS.FOOD_CONSUMPTION_RATE) {
        storedFood -= GLOBALS.FOOD_CONSUMPTION_RATE;
        newHunger = (newHunger - 1) as Hunger;
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
      goldDelta: 0 // Gold deposits are constant per PRD, so we don't reduce the square's resources
    };
  } else {
    // EXPLORE
    const adjs = getAdjacentPositions(agent.pos, grid[0].length, grid.length);
    const randomAdj = adjs[Math.floor(Math.random() * adjs.length)];
    
    let nextHunger = agent.currHunger;
    let nextFoodInv = agent.foodInventory;

    // Small chance to become hungrier each tick randomly, forcing them to find food
    if (Math.random() < 0.05) {
      if (nextHunger === Hunger.None) nextHunger = Hunger.Lo;
      else if (nextHunger === Hunger.Lo) nextHunger = Hunger.Hi;
    }
    
    // Auto-eat food from inventory if hungry
    if (nextHunger > Hunger.None && nextFoodInv > 0) {
      while (nextHunger > Hunger.None && nextFoodInv >= GLOBALS.FOOD_CONSUMPTION_RATE) {
        nextFoodInv -= GLOBALS.FOOD_CONSUMPTION_RATE;
        nextHunger = (nextHunger - 1) as Hunger;
      }
    }

    return {
      agent: {
        ...agent,
        pos: randomAdj,
        currHunger: nextHunger,
        foodInventory: nextFoodInv,
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
      };
    }
    
    return resolution.agent;
  });
  
  return {
    tick: prevState.tick + 1,
    grid: nextGrid,
    agents: nextAgents // New agent states including movements and updated inventories
  };
};
