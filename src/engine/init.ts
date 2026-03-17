import { type WorldState, type Square, type Agent, GLOBALS } from './types';

function generateRandomId(): string {
  return Math.random().toString(36).substr(2, 9);
}

export function generateInitialState(width = 15, height = 15, numAgents = 5): WorldState {
  // 1. Generate grid
  const grid: Square[][] = [];
  for (let y = 0; y < height; y++) {
    const row: Square[] = [];
    for (let x = 0; x < width; x++) {
      const rand = Math.random();
      let type: Square['type'] = 'Dirt';
      let foodResources = 0;
      let goldResources = 0;

      if (rand < 0.2) {
        type = 'Food';
        foodResources = Math.floor(Math.random() * GLOBALS.MAX_FOOD_PER_BLOCK);
      } else if (rand < 0.25) {
        type = 'Gold';
        goldResources = Math.floor(Math.random() * 5) + 1; // 1-5 gold
      }

      row.push({ type, foodResources, goldResources });
    }
    grid.push(row);
  }

  // 2. Generate agents
  const agents: Agent[] = [];
  for (let i = 0; i < numAgents; i++) {
    agents.push({
      id: generateRandomId(),
      pos: {
        x: Math.floor(Math.random() * width),
        y: Math.floor(Math.random() * height),
      },
      currHunger: 0,
      baseGreed: Math.random() * 10, // Float between 0 and 10
      foodInventory: 0,
      goldInventory: 0
    });
  }

  return {
    tick: 0,
    grid,
    agents,
  };
}
