import { VERDICT } from '../../utils/formatters'

export default function ThreatDot({ threat, x, y, selected, pulsing, onClick }) {
  const color = VERDICT.color[threat.verdict] || 'var(--t3)'
  const size = selected || pulsing ? 10 : 6

  return (
    <div
      role="presentation"
      onClick={onClick}
      style={{
        position: 'absolute',
        left: x - size / 2,
        top: y - size / 2,
        width: size,
        height: size,
        cursor: 'pointer',
        zIndex: selected || pulsing ? 15 : 5,
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: pulsing ? -8 : -4,
          borderRadius: '50%',
          border: `${pulsing ? 2 : 1.5}px solid ${color}`,
          animation: pulsing ? 'threat-ring 1.2s ease-out infinite' : 'threat-ring 2s ease-out infinite',
          animationDelay: pulsing ? '0s' : `${Math.random() * 2}s`,
          opacity: 0,
        }}
      />
      <div
        style={{
          width: '100%',
          height: '100%',
          borderRadius: '50%',
          background: color,
          boxShadow: selected ? `0 0 12px 3px ${color}` : `0 0 5px 1px ${color}`,
          transition: 'all 0.2s',
        }}
      />
    </div>
  )
}
