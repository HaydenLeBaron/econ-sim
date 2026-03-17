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
  readonly bornOnTurn: number;
  readonly diedOnTurn?: number;
  readonly color: string;
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

export interface Order {
  agentId: string;
  type: 'BID' | 'ASK';
  price: number;
  qty: number;
}

export interface TradeEvent {
  tick: number;
  buyerId: string;
  sellerId: string;
  price: number;
  qty: number;
}

export interface MarketState {
  bids: Order[];
  asks: Order[];
  lastClearingPrice: number | null;
  volumeLastTick: number;
  tradesLastTick: TradeEvent[];
}

export type WorldState = {
  readonly tick: number;
  readonly grid: ReadonlyArray<ReadonlyArray<Square>>;
  readonly agents: ReadonlyArray<Agent>;
  readonly market: MarketState;
};

export const GLOBALS = {
  MAX_FOOD_PER_BLOCK: 20,
  FOOD_GROWTH_RATE: 0.5,
  FOOD_CONSUMPTION_RATE: 1,
  HUNGER_ACCUMULATED_PER_TURN: 0.3,
  DEATH_AT_HUNGER: 10,
  MAX_PREGNANCY_HUNGER: 4,
  STARTING_AGENT_BABY_HUNGER: 5,
  BIRTHING_HUNGER_COST: 2.5,
  REPRODUCE_PERCENT_CHANCE: 1.0, // 0-1.0 -> 0%-100%
} as const;
