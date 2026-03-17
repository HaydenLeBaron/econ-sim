import { useState, useEffect, useRef } from 'react'
import type { WorldState, Agent, MarketState, TradeEvent } from './engine/types'
import { generateInitialState } from './engine/init'
import { tick } from './engine/tick'
import { calculateMRS, derivePreferenceParams, generateIndifferenceCurve, calculateUtility, calculateMU_Food, calculateMU_Gold } from './engine/math'
import './index.css'

function MarketGraph({ market }: { market: MarketState }) {
  const bids = [...market.bids].sort((a, b) => b.price - a.price); // Descending (highest willingness to pay)
  const asks = [...market.asks].sort((a, b) => a.price - b.price); // Ascending (lowest willingness to sell)

  let cumDemand = 0;
  const demandPoints = bids.map(b => {
    cumDemand += b.qty;
    return { price: b.price, qty: cumDemand };
  });

  let cumSupply = 0;
  const supplyPoints = asks.map(a => {
    cumSupply += a.qty;
    return { price: a.price, qty: cumSupply };
  });

  const maxQty = Math.max(cumDemand, cumSupply, 10);
  const maxP = Math.max(...bids.map(b => b.price), ...asks.map(a => a.price), 5);

  const svgW = 260;
  const svgH = 120;
  const pad = 15;

  const mapX = (q: number) => pad + (q / maxQty) * (svgW - 2 * pad);
  const mapY = (p: number) => svgH - pad - (Math.min(p, maxP) / maxP) * (svgH - 2 * pad);

  const buildStepPath = (points: { price: number, qty: number }[]) => {
    if (points.length === 0) return '';
    let path = `M ${mapX(0)} ${mapY(points[0].price)}`;
    for (let i = 0; i < points.length; i++) {
      const pt = points[i];
      path += ` L ${mapX(pt.qty)} ${mapY(pt.price)}`;
      if (i < points.length - 1) {
        path += ` L ${mapX(pt.qty)} ${mapY(points[i + 1].price)}`;
      }
    }
    return path;
  };

  const demandPath = buildStepPath(demandPoints);
  const supplyPath = buildStepPath(supplyPoints);

  return (
    <svg width="100%" height={svgH} viewBox={`0 0 ${svgW} ${svgH}`} style={{ background: 'rgba(0,0,0,0.2)', borderRadius: '4px', marginTop: '0.5rem' }}>
      {demandPoints.length > 0 && <path d={demandPath} fill="none" stroke="#4ade80" strokeWidth="2" />}
      {supplyPoints.length > 0 && <path d={supplyPath} fill="none" stroke="#fbbf24" strokeWidth="2" />}

      {/* axes */}
      <line x1={pad} y1={svgH - pad} x2={svgW - pad} y2={svgH - pad} stroke="rgba(255,255,255,0.2)" strokeWidth="1" />
      <line x1={pad} y1={pad} x2={pad} y2={svgH - pad} stroke="rgba(255,255,255,0.2)" strokeWidth="1" />
      <text x={svgW - pad} y={svgH - pad + 10} fill="rgba(255,255,255,0.5)" fontSize="8" textAnchor="end">Qty</text>
      <text x={pad - 5} y={pad + 5} fill="rgba(255,255,255,0.5)" fontSize="8" textAnchor="end">P</text>

      {/* Legend */}
      <text x={svgW - pad - 40} y={pad + 5} fill="#4ade80" fontSize="8">Demand</text>
      <text x={svgW - pad - 40} y={pad + 15} fill="#fbbf24" fontSize="8">Supply</text>
    </svg>
  );
}

function GlobalStatRow({ label, nums, format }: { label: string, nums: number[], format?: (n: number) => string | number }) {
  if (nums.length === 0) {
    return (
      <div className="stat-box">
        <span className="stat-label">{label}</span>
        <span className="stat-val">-</span>
      </div>
    );
  }

  const sorted = [...nums].sort((a, b) => a - b);
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  const mid = Math.floor(sorted.length / 2);
  const med = sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  const mean = nums.reduce((sum, val) => sum + val, 0) / nums.length;

  const f = format || ((n: number) => n.toFixed(1));

  return (
    <div className="stat-box" style={{ padding: '0.5rem 0.25rem' }}>
      <span className="stat-label">{label}</span>
      <span className="stat-val" style={{ display: 'flex', gap: '0.5rem' }}>
        <span title="Minimum"><span style={{ fontSize: '0.5rem', color: 'var(--text-secondary)', marginRight: '2px' }}>MIN</span>{f(min)}</span>
        <span title="Mean"><span style={{ fontSize: '0.5rem', color: 'var(--text-secondary)', marginRight: '2px' }}>AVG</span>{f(mean)}</span>
        <span title="Median" style={{ color: 'var(--accent)' }}><span style={{ fontSize: '0.5rem', color: 'var(--text-secondary)', marginRight: '2px' }}>MED</span>{f(med)}</span>
        <span title="Maximum"><span style={{ fontSize: '0.5rem', color: 'var(--text-secondary)', marginRight: '2px' }}>MAX</span>{f(max)}</span>
      </span>
    </div>
  )
}

function TradeLogPane({ trades, onSelectAgent }: { trades: TradeEvent[], onSelectAgent: (id: string) => void }) {
  if (trades.length === 0) return null;

  return (
    <div className="trade-log-pane" style={{
      margin: '0 1rem 1rem 1rem',
      padding: '0.5rem',
      background: 'rgba(0,0,0,0.3)',
      borderRadius: '8px',
      border: '1px solid var(--panel-border)',
      maxHeight: '120px',
      overflowY: 'auto',
      fontSize: '0.75rem',
      fontFamily: 'monospace',
      display: 'flex',
      flexDirection: 'column-reverse',
    }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
        {[...trades].reverse().map((t, i) => (
          <div key={`${t.tick}-${t.buyerId}-${t.sellerId}-${i}`} style={{ display: 'flex', gap: '8px', alignItems: 'baseline' }}>
            <span style={{ color: 'var(--text-secondary)', width: '45px' }}>[T{t.tick.toString().padStart(3, '0')}]</span>
            <span
              style={{ color: '#4ade80', cursor: 'pointer', textDecoration: 'underline' }}
              onClick={() => onSelectAgent(t.buyerId)}
              title="Click to view Buyer"
            >
              {t.buyerId.substring(0, 6)}
            </span>
            <span>bought</span>
            <span style={{ color: '#fbbf24', fontWeight: 'bold' }}>{t.qty}f</span>
            <span>from</span>
            <span
              style={{ color: '#fbbf24', cursor: 'pointer', textDecoration: 'underline' }}
              onClick={() => onSelectAgent(t.sellerId)}
              title="Click to view Seller"
            >
              {t.sellerId.substring(0, 6)}
            </span>
            <span>for</span>
            <span style={{ color: '#fcd34d', fontWeight: 'bold' }}>{(t.qty * t.price).toFixed(2)}g</span>
            <span style={{ color: 'var(--text-secondary)' }}>(@ {t.price.toFixed(2)}/ea)</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function EconomyPane({
  state,
  onSelectAgent,
  marketsEnabled,
  setMarketsEnabled
}: {
  state: WorldState,
  onSelectAgent: (id: string) => void,
  marketsEnabled: boolean,
  setMarketsEnabled: (v: boolean) => void
}) {
  // ECONOMY PANE (Aggregate Stats)
  const living = state.agents.filter(a => !a.isDead);
  const pop = living.length;
  const dead = state.agents.filter(a => a.isDead);

  const [limitInput, setLimitInput] = useState<string>("10");
  const limit = parseInt(limitInput) || 0;

  // Collect values into arrays
  const ages: number[] = [];
  const hungers: number[] = [];
  const greeds: number[] = [];
  const foods: number[] = [];
  const golds: number[] = [];
  const utils: number[] = [];
  const mrss: number[] = [];
  const mufs: number[] = [];
  const mugs: number[] = [];

  living.forEach(a => {
    ages.push(state.tick - a.bornOnTurn);
    hungers.push(a.currHunger);
    greeds.push(a.baseGreed);
    foods.push(a.foodInventory);
    golds.push(a.goldInventory);

    const prefs = derivePreferenceParams(a);
    utils.push(calculateUtility(a.foodInventory, a.goldInventory, prefs));
    mrss.push(calculateMRS(a));
    mufs.push(calculateMU_Food(a));
    mugs.push(calculateMU_Gold(a));
  });

  const deadLifespans = dead.map(a => a.diedOnTurn! - a.bornOnTurn);

  // Calculate Macro Supply Equations
  let totalFoodInFarms = 0;
  let totalGoldInMinesDumps = 0;
  state.grid.forEach(row => row.forEach(sq => {
    totalFoodInFarms += sq.foodResources;
    totalGoldInMinesDumps += sq.goldResources;
  }));

  const totalFoodInv = foods.reduce((sum, val) => sum + val, 0);
  const totalGoldInv = golds.reduce((sum, val) => sum + val, 0);

  const totalFoodSupply = totalFoodInFarms + totalFoodInv;
  const totalGoldSupply = totalGoldInMinesDumps + totalGoldInv;

  return (
    <aside className="inspector economy-pane">
      <h2>Global Economy</h2>

      <div className="macro-supply" style={{ marginBottom: '1.5rem', padding: '1rem', background: 'rgba(0,0,0,0.2)', borderRadius: '8px', border: '1px solid var(--panel-border)' }}>
        <h3 style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '0.5rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Macro Supply Constraints</h3>
        <div style={{ fontSize: '0.75rem', fontFamily: 'monospace', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
          <div>
            <span style={{ color: '#fbbf24' }}>Gold Supply ({totalGoldSupply.toFixed(1)})</span>
            <br />
            <span style={{ opacity: 0.7 }}>= Mines ({totalGoldInMinesDumps.toFixed(1)}) + Inv ({totalGoldInv.toFixed(1)})</span>
          </div>
          <div>
            <span style={{ color: '#4ade80' }}>Food Supply ({totalFoodSupply.toFixed(1)})</span>
            <br />
            <span style={{ opacity: 0.7 }}>= Farms ({totalFoodInFarms.toFixed(1)}) + Inv ({totalFoodInv.toFixed(1)})</span>
          </div>
        </div>
      </div>

      <div className="market-overview" style={{ marginBottom: '1.5rem', padding: '1rem', background: 'rgba(0,0,0,0.2)', borderRadius: '8px', border: '1px solid var(--panel-border)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
          <h3 style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', margin: 0, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Global Market</h3>
          <label style={{ display: 'flex', alignItems: 'center', gap: '4px', cursor: 'pointer', fontSize: '0.7rem' }}>
            <input type="checkbox" checked={marketsEnabled} onChange={e => setMarketsEnabled(e.target.checked)} />
            Enabled
          </label>
        </div>

        {marketsEnabled && (
          <div className="market-stats" style={{ fontSize: '0.75rem', marginTop: '0.5rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span className="stat-label">Last Price (P)</span>
              <span className="stat-val" style={{ color: '#fcd34d' }}>{state.market.lastClearingPrice ? state.market.lastClearingPrice.toFixed(2) : '-'}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span className="stat-label">Volume (Tick)</span>
              <span className="stat-val">{state.market.volumeLastTick}</span>
            </div>
            <div style={{ textAlign: 'center', fontSize: '0.65rem', color: 'var(--text-secondary)', marginBottom: '-4px', marginTop: '12px' }}>Last Turn's Supply & Demand</div>
            <MarketGraph market={state.market} />

            <div className="order-book" style={{ marginTop: '0.75rem', display: 'flex', gap: '8px' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '0.65rem', color: '#4ade80', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '2px', marginBottom: '2px' }}>LAST TURN'S BIDS (Px • Qty)</div>
                {state.market.bids.slice(0, 5).map((b, i) => (
                  <div key={`bid-${i}`} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'monospace' }}>
                    <span>{b.price.toFixed(2)}</span>
                    <span>{b.qty.toFixed(1)}</span>
                  </div>
                ))}
                {state.market.bids.length === 0 && <div style={{ opacity: 0.5, fontFamily: 'monospace' }}>Empty</div>}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '0.65rem', color: '#fbbf24', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '2px', marginBottom: '2px' }}>LAST TURN'S ASKS (Px • Qty)</div>
                {state.market.asks.slice(0, 5).map((a, i) => (
                  <div key={`ask-${i}`} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'monospace' }}>
                    <span>{a.price.toFixed(2)}</span>
                    <span>{a.qty.toFixed(1)}</span>
                  </div>
                ))}
                {state.market.asks.length === 0 && <div style={{ opacity: 0.5, fontFamily: 'monospace' }}>Empty</div>}
              </div>
            </div>
          </div>
        )}
      </div>

      <div className="stat-grid compact">
        <div className="stat-box"><span className="stat-label">Population</span><span className="stat-val">{pop}</span></div>
        <div className="stat-box"><span className="stat-label">Total Dead</span><span className="stat-val">{dead.length}</span></div>
        <GlobalStatRow label="Age" nums={ages} />
        <GlobalStatRow label="Lifespan" nums={deadLifespans} />
        <GlobalStatRow label="Hunger" nums={hungers} />
        <GlobalStatRow label="Greed" nums={greeds} />
        <GlobalStatRow label="Food Inv" nums={foods} />
        <GlobalStatRow label="Gold Inv" nums={golds} />
        <GlobalStatRow label="Utility (U)" nums={utils} format={(n) => n.toLocaleString(undefined, { maximumFractionDigits: 1 })} />
        <GlobalStatRow label="MRS" nums={mrss} format={(n) => n.toLocaleString(undefined, { maximumFractionDigits: 2 })} />
        <GlobalStatRow label="MU_F" nums={mufs} format={(n) => n.toLocaleString(undefined, { maximumFractionDigits: 2 })} />
        <GlobalStatRow label="MU_G" nums={mugs} format={(n) => n.toLocaleString(undefined, { maximumFractionDigits: 2 })} />
      </div>

      <div className="leaderboard" style={{ marginTop: '2rem', borderTop: '1px solid var(--panel-border)', paddingTop: '1.5rem' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <h3 style={{ fontSize: '0.9rem', margin: 0 }}>Wealthiest Agents</h3>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
            Top:
            <input
              type="number"
              value={limitInput}
              onChange={(e) => setLimitInput(e.target.value)}
              style={{ width: '40px', background: 'rgba(0,0,0,0.3)', border: '1px solid var(--panel-border)', color: 'white', padding: '2px 4px', borderRadius: '4px', fontSize: '0.75rem' }}
            />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
          {living
            .sort((a, b) => (b.foodInventory + b.goldInventory) - (a.foodInventory + a.goldInventory))
            .slice(0, limit)
            .map((agent, i) => (
              <div
                key={agent.id}
                onClick={() => onSelectAgent(agent.id)}
                className="leaderboard-row"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  background: 'rgba(255,255,255,0.03)',
                  padding: '2px 6px',
                  borderRadius: '3px',
                  fontSize: '0.7rem',
                  cursor: 'pointer',
                  border: '1px solid transparent'
                }}
              >
                <div style={{ width: '16px', color: 'var(--text-secondary)', fontWeight: 600 }}>{i + 1}.</div>
                <div style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: agent.color, marginRight: '6px' }}></div>
                <div style={{ flex: 1, fontFamily: 'monospace' }}>{agent.id.substring(0, 6)}</div>
                <div style={{ display: 'flex', gap: '8px', fontFamily: 'monospace' }}>
                  <span style={{ color: '#4ade80' }}>{agent.foodInventory.toFixed(2)}f</span>
                  <span style={{ color: '#fbbf24' }}>{agent.goldInventory.toFixed(2)}g</span>
                  <span style={{ fontWeight: 800 }}>({(agent.foodInventory + agent.goldInventory).toFixed(2)})</span>
                </div>
              </div>
            ))
          }
          {living.length === 0 && <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>No living agents.</div>}
        </div>
      </div>
    </aside>
  )
}

function SingleAgentStats({ agent }: { agent: Agent }) {
  // Dynamic bounds scaled to the agent's current reality.
  const MAX_FOOD = Math.max(4, Math.ceil(agent.foodInventory * 2.5));
  const MAX_GOLD = Math.max(4, Math.ceil(agent.goldInventory * 2.5)); // Cap visual y-axis

  const prefs = derivePreferenceParams(agent);
  const mrs = calculateMRS(agent);
  const totalU = calculateUtility(agent.foodInventory, agent.goldInventory, prefs);
  const muF = calculateMU_Food(agent);
  const muG = calculateMU_Gold(agent);
  const curve = generateIndifferenceCurve(agent, MAX_FOOD);

  // SVG rendering for curve
  const svgWidth = 260;
  const svgHeight = 260;
  const padding = 35;

  const mapX = (x: number) => padding + (x / MAX_FOOD) * (svgWidth - 2 * padding);
  const mapY = (y: number) => svgHeight - padding - (Math.min(y, MAX_GOLD) / MAX_GOLD) * (svgHeight - 2 * padding);

  const pathD = curve.map((pt, i) => `${i === 0 ? 'M' : 'L'} ${mapX(pt.x)} ${mapY(pt.y)}`).join(' ');

  const currX = mapX(agent.foodInventory);
  const currY = mapY(agent.goldInventory);

  return (
    <>
      <div className="agent-stats">

        <div className="stat-grid compact">
          <div className="stat-box"><span className="stat-label">Born On</span><span className="stat-val">{agent.bornOnTurn}</span></div>
          <div className="stat-box"><span className="stat-label">Died On</span><span className="stat-val">{agent.diedOnTurn || '-'}</span></div>
          <div className="stat-box">
            <span className="stat-label">Hunger</span>
            <span className="stat-val">{agent.currHunger.toFixed(1)}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">Greed</span>
            <span className="stat-val">{agent.baseGreed.toFixed(1)}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">Food Inv</span>
            <span className="stat-val">{agent.foodInventory.toFixed(2)}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">Gold Inv</span>
            <span className="stat-val">{agent.goldInventory.toFixed(2)}</span>
          </div>
        </div>
      </div>

      <div className="preference-curve">
        <h3>Economic Parameters</h3>
        <div className="stat-grid compact" style={{ marginTop: 0, marginBottom: '2rem' }}>
          <div className="stat-box">
            <span className="stat-label">α (Food)</span>
            <span className="stat-val">{prefs.alpha.toFixed(1)}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">β (Gold)</span>
            <span className="stat-val">{prefs.beta.toFixed(1)}</span>
          </div>
          <div className="stat-box" style={{ gridColumn: 'span 2' }}>
            <span className="stat-label">Total Utility (U)</span>
            <span className="stat-val" style={{ color: 'var(--accent)' }}>{totalU.toLocaleString(undefined, { maximumFractionDigits: 1 })}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">MU_F (Food)</span>
            <span className="stat-val">{muF.toLocaleString(undefined, { maximumFractionDigits: 2 })}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">MU_G (Gold)</span>
            <span className="stat-val">{muG.toLocaleString(undefined, { maximumFractionDigits: 2 })}</span>
          </div>
          <div className="stat-box" style={{ gridColumn: 'span 2' }}>
            <span className="stat-label">MRS</span>
            <span className="stat-val" style={{ color: '#fcd34d' }}>{mrs.toLocaleString(undefined, { maximumFractionDigits: 3 })}</span>
          </div>
        </div>

        <h3>Indifference Curve</h3>
        <div className="curve-chart">
          <span className="axis-label y">Gold </span>
          <span className="axis-label x">Food</span>

          <svg width="100%" height="100%" viewBox={`0 0 ${svgWidth} ${svgHeight}`}>
            <line x1={padding} y1={padding} x2={padding} y2={svgHeight - padding} stroke="rgba(255,255,255,0.2)" strokeWidth="2" />
            <line x1={padding} y1={svgHeight - padding} x2={svgWidth - padding} y2={svgHeight - padding} stroke="rgba(255,255,255,0.2)" strokeWidth="2" />

            {Array.from({ length: 4 }).map((_, i) => {
              const val = Math.round((i + 1) * (MAX_FOOD / 4));
              const x = mapX(val);
              return (
                <g key={`x-${i}`}>
                  <line x1={x} y1={svgHeight - padding} x2={x} y2={svgHeight - padding + 5} stroke="rgba(255,255,255,0.5)" strokeWidth="1" />
                  <text x={x} y={svgHeight - padding + 18} fill="rgba(255,255,255,0.5)" fontSize="10" textAnchor="middle">{val}</text>
                </g>
              )
            })}

            {Array.from({ length: 4 }).map((_, i) => {
              const val = Math.round((i + 1) * (MAX_GOLD / 4));
              const y = mapY(val);
              return (
                <g key={`y-${i}`}>
                  <line x1={padding - 5} y1={y} x2={padding} y2={y} stroke="rgba(255,255,255,0.5)" strokeWidth="1" />
                  <text x={padding - 8} y={y + 3} fill="rgba(255,255,255,0.5)" fontSize="10" textAnchor="end">{val}</text>
                </g>
              )
            })}

            <path d={pathD} fill="none" stroke="var(--accent)" strokeWidth="3" />
            <circle cx={currX} cy={currY} r="6" fill={agent.color || "var(--agent-selected)"} />
          </svg>
        </div>
      </div>
    </>
  )
}

function AgentPane({ agents }: { agents: Agent[] }) {
  if (agents.length === 0) {
    return (
      <aside className="inspector agent-pane">
        <div className="inspector-placeholder">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" />
            <path d="M12 16v-4" />
            <path d="M12 8h.01" />
          </svg>
          <p>Select an agent to view their economic preferences</p>
        </div>
      </aside>
    )
  }

  return (
    <aside className="inspector agent-pane">
      {agents.length === 1 ? (
        <>
          <div className="accordion-header" style={{ border: 'none' }}>
            <div className="agent-color-swatch" style={{ backgroundColor: agents[0].color, borderColor: agents[0].color }}></div>
            <h2 style={{ margin: 0 }}>Agent {agents[0].id}</h2>
          </div>
          <SingleAgentStats agent={agents[0]} />
        </>
      ) : (
        <>
          <h2>{agents.length} Grouped Agents</h2>
          <div className="agent-accordion">
            {agents.map(agent => (
              <div key={agent.id} className="accordion-item">
                <div className="accordion-header">
                  <div className="agent-color-swatch" style={{ backgroundColor: agent.color, borderColor: agent.color }}></div>
                  <h3 style={{ margin: 0, fontSize: '1rem' }}>Agent {agent.id}</h3>
                  {agent.isDead && <span style={{ marginLeft: 'auto', backgroundColor: '#991b1b', padding: '2px 6px', borderRadius: '4px', fontSize: '10px', color: 'white' }}>DEAD</span>}
                </div>
                <SingleAgentStats agent={agent} />
              </div>
            ))}
          </div>
        </>
      )}
    </aside>
  )
}

function App() {
  const [history, setHistory] = useState<WorldState[]>([]);
  const [currIndex, setCurrIndex] = useState(0);
  const [selectedAgentIds, setSelectedAgentIds] = useState<string[]>([]);

  const [isPlaying, setIsPlaying] = useState(false);
  const playIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const initial = generateInitialState(20, 15, 50);
    setHistory([initial]);
  }, []);

  const currentState = history[currIndex];

  const [marketsEnabled, setMarketsEnabled] = useState(true);

  const handleNextTick = () => {
    setHistory(prev => {
      const currentHist = prev.slice(0, currIndex + 1);
      const nextState = tick(currentHist[currentHist.length - 1], { marketsEnabled });
      return [...currentHist, nextState];
    });
    setCurrIndex(prev => prev + 1);
  };

  useEffect(() => {
    if (isPlaying) {
      playIntervalRef.current = setInterval(() => {
        handleNextTick();
      }, 500);
    } else {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    }
    return () => {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    };
  }, [isPlaying, currIndex, history, marketsEnabled]);

  if (!currentState) return null;

  const selectedAgents = currentState.agents.filter(a => selectedAgentIds.includes(a.id));

  // Compute flat chronological trades up to current tick
  const allHistoricalTrades = history.slice(0, currIndex + 1).flatMap(s => s.market.tradesLastTick);

  return (
    <div className="app-container">
      <EconomyPane
        state={currentState}
        onSelectAgent={(id) => setSelectedAgentIds([id])}
        marketsEnabled={marketsEnabled}
        setMarketsEnabled={setMarketsEnabled}
      />

      <main className="main-content">
        <header className="header">
          <h1>Economic Simulation Engine</h1>
        </header>

        <TradeLogPane trades={allHistoricalTrades} onSelectAgent={(id) => setSelectedAgentIds([id])} />

        <section className="board-wrapper">
          <div
            className="grid"
            style={{
              gridTemplateColumns: `repeat(${currentState.grid[0]?.length || 0}, 40px)`,
              gridTemplateRows: `repeat(${currentState.grid.length || 0}, 40px)`
            }}
          >
            {currentState.grid.map((row, y) => (
              row.map((sq, x) => {
                const agentsHere = currentState.agents.filter(a => a.pos.x === x && a.pos.y === y);
                const livingAgentsHere = agentsHere.filter(a => !a.isDead);
                const deadAgentsHere = agentsHere.filter(a => a.isDead);

                const isSelectedLivingGroup = livingAgentsHere.some(a => selectedAgentIds.includes(a.id));
                const isSelectedDeadGroup = deadAgentsHere.some(a => selectedAgentIds.includes(a.id));

                // Offset dead stack so it's visible even if there are living agents
                const deadBaseOffsetX = livingAgentsHere.length > 0 ? 10 : 0;
                const deadBaseOffsetY = livingAgentsHere.length > 0 ? -10 : 0;

                return (
                  <div key={`${x}-${y}`} className={`square ${sq.type}`}>
                    {sq.foodResources > 0 && <span className="resource-food">{Number(sq.foodResources.toFixed(2))}f</span>}
                    {sq.goldResources > 0 && <span className="resource-gold">{Number(sq.goldResources.toFixed(2))}</span>}

                    {/* Living Stack */}
                    {livingAgentsHere.length >= 5 ? (
                      <div
                        className={`agent grouped living ${isSelectedLivingGroup ? 'selected' : ''}`}
                        onClick={() => setSelectedAgentIds(livingAgentsHere.map(a => a.id))}
                        style={{ zIndex: 10 }}
                      >
                        {livingAgentsHere.length}
                      </div>
                    ) : (
                      livingAgentsHere.map((agent, i) => (
                        <div
                          key={agent.id}
                          className={`agent living ${selectedAgentIds.includes(agent.id) ? 'selected' : ''}`}
                          onClick={() => setSelectedAgentIds([agent.id])}
                          style={{
                            backgroundColor: agent.color,
                            transform: i > 0 ? `translate(${i * 4}px, ${i * 4}px)` : 'none',
                            zIndex: 10 + i
                          }}
                        >
                        </div>
                      ))
                    )}

                    {/* Dead Stack */}
                    {deadAgentsHere.length >= 5 ? (
                      <div
                        className={`agent grouped dead ${isSelectedDeadGroup ? 'selected' : ''}`}
                        onClick={() => setSelectedAgentIds(deadAgentsHere.map(a => a.id))}
                        style={{ transform: `translate(${deadBaseOffsetX}px, ${deadBaseOffsetY}px)`, zIndex: 5 }}
                      >
                        {deadAgentsHere.length}
                      </div>
                    ) : (
                      deadAgentsHere.map((agent, i) => (
                        <div
                          key={agent.id}
                          className={`agent dead ${selectedAgentIds.includes(agent.id) ? 'selected' : ''}`}
                          onClick={() => setSelectedAgentIds([agent.id])}
                          style={{
                            transform: `translate(${deadBaseOffsetX + i * 4}px, ${deadBaseOffsetY + i * 4}px)`,
                            zIndex: 5 + i
                          }}
                        >
                          <span className="dead-mark">X</span>
                          {selectedAgentIds.includes(agent.id) && (
                            <div className="dead-tooltip">Died term {agent.diedOnTurn}</div>
                          )}
                        </div>
                      ))
                    )}
                  </div>
                )
              })
            ))}
          </div>
        </section>

        <section className="timeline">
          <div className="controls">
            <button onClick={() => setIsPlaying(!isPlaying)}>
              {isPlaying ? 'Pause' : 'Play'}
            </button>
            <button onClick={handleNextTick} disabled={isPlaying} style={{ marginLeft: '0.5rem' }}>
              Step Forward
            </button>
          </div>

          <div className="slider-container">
            <input
              type="range"
              min={0}
              max={history.length - 1}
              value={currIndex}
              onChange={(e) => {
                setCurrIndex(parseInt(e.target.value));
                setIsPlaying(false);
              }}
            />
            <span className="tick-display">Tick {currentState.tick}</span>
          </div>
        </section>
      </main>

      <AgentPane agents={selectedAgents} />
    </div>
  )
}

export default App
