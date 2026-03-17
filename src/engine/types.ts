export type Hunger = 0 | 1 | 2;
export const Hunger = {
  None: 0,
  Lo: 1,
  Hi: 2,
} as const;

export type Greed = 0 | 1 | 2;
export const Greed = {
  None: 0,
  Lo: 1,
  Hi: 2,
} as const;

export type Position = {
  readonly x: number;
  readonly y: number;
};

export type Agent = {
  readonly id: string;
  readonly pos: Position;
  readonly currHunger: Hunger;
  readonly baseGreed: Greed;
  readonly foodInventory: number;
  readonly goldInventory: number;
};

export type SquareType = 'Dirt' | 'Food' | 'Gold';

export type SquareColor = 'Brown' | 'Green' | 'Gold';

export const getSquareColor = (type: SquareType): SquareColor => {
  switch (type) {
    case 'Dirt': return 'Brown';
    case 'Food': return 'Green';
    case 'Gold': return 'Gold';
  }
};

export type Square = {
  readonly type: SquareType;
  readonly foodResources: number;
  readonly goldResources: number;
};

export type WorldState = {
  readonly tick: number;
  readonly grid: ReadonlyArray<ReadonlyArray<Square>>;
  readonly agents: ReadonlyArray<Agent>;
};

export const GLOBALS = {
  MAX_FOOD_PER_BLOCK: 10,
  FOOD_GROWTH_RATE: 1,
  FOOD_CONSUMPTION_RATE: 1,
} as const;
