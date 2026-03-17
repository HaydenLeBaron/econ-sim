import { useState, useEffect, useRef } from 'react'
import type { WorldState, Agent } from './engine/types'
import { generateInitialState } from './engine/init'
import { tick } from './engine/tick'
import { calculateMRS, derivePreferenceParams, generateIndifferenceCurve, calculateUtility, calculateMU_Food, calculateMU_Gold } from './engine/math'
import './index.css'

function Inspector({ agent }: { agent: Agent | null }) {
  if (!agent) {
    return (
      <aside className="inspector">
        <div className="inspector-placeholder">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10"/>
            <path d="M12 16v-4"/>
            <path d="M12 8h.01"/>
          </svg>
          <p>Select an agent to view their economic preferences</p>
        </div>
      </aside>
    )
  }

  // Dynamic bounds scaled to the agent's current reality
  const MAX_FOOD = Math.max(10, Math.ceil(agent.foodInventory * 2.5));
  const MAX_GOLD = Math.max(10, Math.ceil(agent.goldInventory * 2.5)); // Cap visual y-axis

  const prefs = derivePreferenceParams(agent);
  const mrs = calculateMRS(agent);
  const totalU = calculateUtility(agent.foodInventory, agent.goldInventory, prefs);
  const muF = calculateMU_Food(agent);
  const muG = calculateMU_Gold(agent);
  const curve = generateIndifferenceCurve(agent, MAX_FOOD);

  // SVG rendering for curve
  const svgWidth = 260;
  const svgHeight = 260;
  const padding = 35; // Increased padding to fit tick labels
  
  const mapX = (x: number) => padding + (x / MAX_FOOD) * (svgWidth - 2 * padding);
  const mapY = (y: number) => svgHeight - padding - (Math.min(y, MAX_GOLD) / MAX_GOLD) * (svgHeight - 2 * padding);

  const pathD = curve.map((pt, i) => `${i === 0 ? 'M' : 'L'} ${mapX(pt.x)} ${mapY(pt.y)}`).join(' ');

  const currX = mapX(agent.foodInventory);
  const currY = mapY(agent.goldInventory);

  return (
    <aside className="inspector">
      <div className="agent-stats">
        <h2>Agent {agent.id}</h2>
        
        <div className="stat-grid">
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
            <span className="stat-val">{agent.foodInventory}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">Gold Inv</span>
            <span className="stat-val">{agent.goldInventory}</span>
          </div>
        </div>
      </div>

      <div className="preference-curve">
        <h3>Economic Parameters</h3>
        <div className="stat-grid" style={{marginTop: 0, marginBottom: '2rem'}}>
          <div className="stat-box">
            <span className="stat-label">α (Food Bias)</span>
            <span className="stat-val">{prefs.alpha.toFixed(1)}</span>
          </div>
          <div className="stat-box">
            <span className="stat-label">β (Gold Bias)</span>
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
            <span className="stat-label">Marginal Rate of Substitution (MRS)</span>
            <span className="stat-val" style={{ color: '#fcd34d' }}>{mrs.toLocaleString(undefined, { maximumFractionDigits: 3 })}</span>
          </div>
        </div>

        <h3>Indifference Curve</h3>
        <div className="curve-chart">
          <span className="axis-label y">Gold </span>
          <span className="axis-label x">Food</span>
          
          <svg width="100%" height="100%" viewBox={`0 0 ${svgWidth} ${svgHeight}`}>
            {/* Axes */}
            <line x1={padding} y1={padding} x2={padding} y2={svgHeight - padding} stroke="rgba(255,255,255,0.2)" strokeWidth="2" />
            <line x1={padding} y1={svgHeight - padding} x2={svgWidth - padding} y2={svgHeight - padding} stroke="rgba(255,255,255,0.2)" strokeWidth="2" />
            
            {/* X Axis Ticks */}
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

            {/* Y Axis Ticks */}
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

            {/* The Curve */}
            <path d={pathD} fill="none" stroke="var(--accent)" strokeWidth="3" />
            
            {/* Current Point */}
            <circle cx={currX} cy={currY} r="6" fill="var(--agent-selected)" />
          </svg>
        </div>
      </div>
    </aside>
  )
}

function App() {
  const [history, setHistory] = useState<WorldState[]>([]);
  const [currIndex, setCurrIndex] = useState(0);
  const [selectedAgentId, setSelectedAgentId] = useState<string | null>(null);
  
  const [isPlaying, setIsPlaying] = useState(false);
  const playIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    const initial = generateInitialState(20, 15, 8);
    setHistory([initial]);
  }, []);

  const currentState = history[currIndex];

  const handleNextTick = () => {
    setHistory(prev => {
      // If we're not at the latest state when we generate a new tick, we branch history.
      // Easiest is to just truncate history to current index.
      const currentHist = prev.slice(0, currIndex + 1);
      const nextState = tick(currentHist[currentHist.length - 1]);
      return [...currentHist, nextState];
    });
    setCurrIndex(prev => prev + 1);
  };

  useEffect(() => {
    if (isPlaying) {
      playIntervalRef.current = setInterval(() => {
        handleNextTick();
      }, 500); // 500ms per tick
    } else {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    }
    return () => {
      if (playIntervalRef.current) clearInterval(playIntervalRef.current);
    };
  }, [isPlaying, currIndex, history]); // Dependencies needed because handleNextTick uses setHistory and relies on state

  if (!currentState) return null;

  const selectedAgent = currentState.agents.find(a => a.id === selectedAgentId) || null;

  return (
    <div className="app-container">
      <main className="main-content">
        <header className="header">
          <h1>Economic Simulation Engine</h1>
        </header>

        <section className="board-wrapper">
          <div 
            className="grid"
            style={{ 
              gridTemplateColumns: `repeat(${currentState.grid[0]?.length || 0}, 40px)`,
              gridTemplateRows: `repeat(${currentState.grid.length || 0}, 40px)`
            }}
          >
            {currentState.grid.map((row, y) => (
              row.map((sq, x) => (
                <div key={`${x}-${y}`} className={`square ${sq.type}`}>
                  {sq.type === 'Food' && sq.foodResources > 0 && <span>{sq.foodResources}</span>}
                  {sq.type === 'Gold' && sq.goldResources > 0 && <span>{sq.goldResources}</span>}
                  
                  {currentState.agents.filter(a => a.pos.x === x && a.pos.y === y).map((agent, i) => (
                    <div 
                      key={agent.id}
                      className={`agent ${agent.id === selectedAgentId ? 'selected' : ''} ${agent.isDead ? 'dead' : ''}`}
                      onClick={() => setSelectedAgentId(agent.id)}
                      style={{
                        // Slight offset if multiple agents on same square
                        transform: i > 0 ? `translate(${i * 4}px, ${i * 4}px)` : 'none'
                      }}
                    >
                      {agent.isDead && <span className="dead-mark">X</span>}
                      {agent.isDead && agent.id === selectedAgentId && (
                        <div className="dead-tooltip">Died tick {agent.diedAtTick}</div>
                      )}
                    </div>
                  ))}
                </div>
              ))
            ))}
          </div>
        </section>

        <section className="timeline">
          <div className="controls">
            <button onClick={() => setIsPlaying(!isPlaying)}>
              {isPlaying ? 'Pause' : 'Play'}
            </button>
            <button onClick={handleNextTick} disabled={isPlaying} style={{marginLeft: '0.5rem'}}>
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

      <Inspector agent={selectedAgent} />
    </div>
  )
}

export default App
