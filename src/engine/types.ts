export type Position = {
  readonly x: number;
  readonly y: number;
};

export type Agent = {
  readonly id: string;
  readonly pos: Position;
  readonly currHunger: number;
  readonly baseGreed: number;
  readonly foodInventory: number;
  readonly goldInventory: number;
  readonly isDead?: boolean;
  readonly diedAtTick?: number;
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
  MAX_FOOD_PER_BLOCK: 5,
  FOOD_GROWTH_RATE: 0.5,
  FOOD_CONSUMPTION_RATE: 1,
  HUNGER_ACCUMULATED_PER_TURN: 1,
  DEATH_AT_HUNGER: 10,
} as const;
