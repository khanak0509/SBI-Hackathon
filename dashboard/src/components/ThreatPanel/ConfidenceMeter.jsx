import { VERDICT } from '../../utils/formatters'

export default function ConfidenceMeter({ confidence, verdict }) {
  const color = VERDICT.color[verdict] || 'var(--t3)'
  const displayVal = ((confidence || 0) * 100).toFixed(1)
  const barWidth = Math.min(100, Math.max(0, (confidence || 0) * 100))
  
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ fontSize: 12, color: 'var(--t2)', fontWeight: 600 }}>Risk Score</span>
        <span style={{ fontSize: 15, fontWeight: 800, color, fontFamily: 'JetBrains Mono, monospace' }}>{displayVal}%</span>
      </div>
      <div style={{ height: 8, background: 'var(--b1)', borderRadius: 4, overflow: 'hidden', border: '1px solid var(--b2)' }}>
        <div
          style={{
            width: `${barWidth}%`,
            height: '100%',
            background: color,
            borderRadius: 4,
            transition: 'width 1s cubic-bezier(0.16,1,0.3,1)',
            boxShadow: `0 0 10px ${color}88`,
          }}
        />
      </div>
    </div>
  )
}
