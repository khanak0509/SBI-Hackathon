import { VERDICT, timeAgo, pct, threatPlaceLabel } from '../../utils/formatters'

export default function ThreatFeedCard({ threat, selected, onClick }) {
  const color = VERDICT.color[threat.verdict] || 'var(--t3)'
  const label = VERDICT.label[threat.verdict] || threat.verdict?.toUpperCase()
  const sub =
    threat.threat_type === 'apk'
      ? threat.apk_package_name || threat.raw_input || '—'
      : threat.malicious_domain || threat.raw_input || '—'
  const loc = threatPlaceLabel(threat)

  return (
    <div
      role="presentation"
      onClick={onClick}
      style={{
        padding: '13px 18px',
        borderBottom: '1px solid var(--b1)',
        cursor: 'pointer',
        background: selected ? 'var(--gold-d)' : 'transparent',
        borderLeft: selected ? `3px solid ${color}` : '3px solid transparent',
        animation: 'slide-down 0.22s ease-out',
        transition: 'background 0.15s',
      }}
    >
      {/* Row 1: verdict + time */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: color,
              boxShadow: `0 0 7px ${color}`,
              animation: 'blink 2s infinite',
              flexShrink: 0,
            }}
          />
          <span style={{ fontWeight: 700, fontSize: 13, color, letterSpacing: '0.4px' }}>{label}</span>
        </div>
        <span style={{ fontSize: 12, color: 'var(--t3)', fontFamily: 'JetBrains Mono, monospace' }}>
          {timeAgo(threat.created_at)}
        </span>
      </div>

      {/* Row 2: package / domain */}
      <div
        style={{
          fontSize: 14,
          fontFamily: 'JetBrains Mono, monospace',
          color: 'var(--t1)',
          fontWeight: 500,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          marginBottom: 7,
        }}
      >
        {sub}
      </div>

      {/* Row 3: location + confidence */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 12, color: 'var(--t3)' }}>{loc || '—'}</span>
        <span
          style={{
            fontSize: 12,
            fontWeight: 700,
            fontFamily: 'JetBrains Mono, monospace',
            background: VERDICT.dim[threat.verdict],
            border: `1px solid ${VERDICT.border[threat.verdict]}`,
            color,
            borderRadius: 4,
            padding: '2px 8px',
          }}
        >
          {pct(threat.confidence)}
        </span>
      </div>
    </div>
  )
}
