import type { Agent, Order, MarketState, TradeEvent } from './types';
import { calculateMRS } from './math';

export const generateOrders = (agents: Agent[]): { bids: Order[]; asks: Order[] } => {
  const bids: Order[] = [];
  const asks: Order[] = [];

  agents.forEach(agent => {
    if (agent.isDead) return;

    const mrs = calculateMRS(agent);
    
    // Safety check for non-finite or 0 MRS
    if (!isFinite(mrs) || isNaN(mrs) || mrs <= 0) return;

    if (mrs > 1.0) {
      // Natural Buyer: Willing to pay up to `mrs` Gold per 1 Food.
      // Max Food they can afford is `goldInventory / mrs`
       const maxQty = Math.floor(agent.goldInventory / mrs);
       if (maxQty > 0) {
         bids.push({
           agentId: agent.id,
           type: 'BID',
           price: mrs,
           qty: maxQty
         });
       }
    } else if (mrs < 1.0) {
       // Natural Seller: Willing to sell 1 Food for at least `mrs` Gold.
       // Max Food they can sell is their entire `foodInventory`
       const maxQty = agent.foodInventory;
       if (maxQty > 0) {
         asks.push({
           agentId: agent.id,
           type: 'ASK',
           price: mrs,
           qty: maxQty
         });
       }
    }
  });

  return { bids, asks };
};

export const resolveMarket = (
  bids: Order[], 
  asks: Order[], 
  agents: Agent[],
  tick: number
): { updatedAgents: Agent[]; marketState: MarketState } => {
  
  // Clone pristine orders to expose the full macroscopic supply/demand curves to the UI
  const pristineBids = bids.map(b => ({ ...b })).sort((a, b) => b.price - a.price);
  const pristineAsks = asks.map(a => ({ ...a })).sort((a, b) => a.price - b.price);

  // Sort Bids descending (highest willingness to pay first)
  const sortedBids = [...bids].sort((a, b) => b.price - a.price);
  // Sort Asks ascending (lowest willingness to accept first)
  const sortedAsks = [...asks].sort((a, b) => a.price - b.price);

  let currentBidIdx = 0;
  let currentAskIdx = 0;

  // We need to mutate agent states sequentially as trades happen
  // Copy the agent map for quick lookup and O(1) replace
  const agentMap = new Map<string, Agent>();
  agents.forEach(a => agentMap.set(a.id, a));

  let lastClearingPrice: number | null = null;
  let volumeLastTick = 0;
  const tradesLastTick: TradeEvent[] = [];

  while (currentBidIdx < sortedBids.length && currentAskIdx < sortedAsks.length) {
    const bid = sortedBids[currentBidIdx];
    const ask = sortedAsks[currentAskIdx];

    if (bid.price >= ask.price && bid.qty > 0 && ask.qty > 0) {
      const matchPrice = (bid.price + ask.price) / 2;
      let matchVolume = Math.min(bid.qty, ask.qty);
      
      const buyer = agentMap.get(bid.agentId);
      const seller = agentMap.get(ask.agentId);
      
      if (!buyer || !seller) {
         if (!buyer) bid.qty = 0;
         if (!seller) ask.qty = 0;
         continue;
      }
      
      // Before executing, enforce hard inventory constraints just in case
      // Buyer has enough gold?
      const maxAffordableVolume = Math.floor(buyer.goldInventory / matchPrice);
      // Seller has enough food?
      const maxSellableVolume = seller.foodInventory;
      
      matchVolume = Math.min(matchVolume, maxAffordableVolume, maxSellableVolume);
      
      if (matchVolume <= 0) {
        // Can't actuate trade: void the constraint
        if (maxAffordableVolume <= 0) bid.qty = 0;
        if (maxSellableVolume <= 0) ask.qty = 0;
        continue;
      }

      // Execute Trade natively!
      agentMap.set(buyer.id, {
        ...buyer,
        goldInventory: buyer.goldInventory - (matchVolume * matchPrice),
        foodInventory: buyer.foodInventory + matchVolume
      });

      agentMap.set(seller.id, {
        ...seller,
        goldInventory: seller.goldInventory + (matchVolume * matchPrice),
        foodInventory: seller.foodInventory - matchVolume
      });

      lastClearingPrice = matchPrice;
      volumeLastTick += matchVolume;
      
      tradesLastTick.push({
        tick,
        buyerId: buyer.id,
        sellerId: seller.id,
        price: matchPrice,
        qty: matchVolume
      });
      
      // Reduce fulfilled order quantities
      bid.qty -= matchVolume;
      ask.qty -= matchVolume;
    } else {
      // Market cleared, spread is positive (bid < ask) and trade is mutually destructive
      break;
    }

    // Advance orders if exhausted
    if (bid.qty <= 0) currentBidIdx++;
    if (ask.qty <= 0) currentAskIdx++;
  }

  // Convert map back to array. Order might have shifted but that's fine. 
  // We can guarantee exact order by mapping original array over the map:
  const updatedAgents = agents.map(a => agentMap.get(a.id)!);

  return {
    updatedAgents,
    marketState: {
      bids: pristineBids,
      asks: pristineAsks,
      lastClearingPrice,
      volumeLastTick,
      tradesLastTick
    }
  };
};
