import { Fragment } from 'react'

const RISK_COLORS = { HIGH: 'var(--red)', MEDIUM: 'var(--amber)', LOW: 'var(--green)' }

function permShort(p) {
  return p.replace('android.permission.', '').replace(/_/g, ' ').toLowerCase()
}

export default function BehaviorAnalysis({ behavior }) {
  const {
    risk_level,
    behavior_risk_score,
    dangerous_combos_detected,
    high_risk_permissions,
    total_permissions,
  } = behavior
  const color = RISK_COLORS[risk_level] || 'var(--t3)'

  return (
    <div style={{ background: 'var(--s1)', border: '1px solid var(--b1)', borderRadius: 10, padding: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 12 }}>
        <span style={{ fontSize: 11, fontFamily: 'JetBrains Mono, monospace', letterSpacing: 2, color: 'var(--t2)', fontWeight: 700 }}>
          BEHAVIORAL ANALYSIS
        </span>
        <div style={{ flex: 1 }} />
        <span
          style={{
            fontSize: 11,
            fontWeight: 700,
            padding: '3px 9px',
            borderRadius: 4,
            background: `${color}18`,
            border: `1px solid ${color}44`,
            color,
          }}
        >
          {risk_level}
        </span>
      </div>

      <div style={{ height: 5, background: 'var(--s2)', borderRadius: 3, overflow: 'hidden', marginBottom: 14 }}>
        <div
          style={{
            width: `${(behavior_risk_score || 0) * 100}%`,
            height: '100%',
            background: `linear-gradient(90deg, ${color}88, ${color})`,
            transition: 'width 0.8s',
            borderRadius: 3,
            boxShadow: `0 0 6px ${color}66`,
          }}
        />
      </div>

      {dangerous_combos_detected?.length > 0 && (
        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--red)', marginBottom: 6 }}>⚠ Dangerous Combinations</div>
          {dangerous_combos_detected.map((combo, i) => (
            <div
              key={i}
              style={{
                background: 'var(--red-d)',
                border: '1px solid var(--red-b)',
                borderRadius: 6,
                padding: '8px 10px',
                marginBottom: 6,
                display: 'flex',
                flexWrap: 'wrap',
                gap: 6,
                alignItems: 'center',
              }}
            >
              {combo.map((p, j) => (
                <Fragment key={`${i}-${j}-${p}`}>
                  <span
                    style={{
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono, monospace',
                      color: 'var(--red)',
                      background: 'rgba(224,85,85,0.15)',
                      borderRadius: 4,
                      padding: '2px 6px',
                    }}
                  >
                    {permShort(p)}
                  </span>
                  {j < combo.length - 1 && (
                    <span style={{ fontSize: 11, color: 'var(--red)', fontWeight: 700 }}>+</span>
                  )}
                </Fragment>
              ))}
            </div>
          ))}
        </div>
      )}

      {high_risk_permissions?.length > 0 && (
        <div style={{ marginBottom: 12 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--amber)', marginBottom: 6 }}>⚠ High-Risk Permissions</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 5 }}>
            {high_risk_permissions.map((p, idx) => (
              <span
                key={`${p}-${idx}`}
                style={{
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono, monospace',
                  color: 'var(--amber)',
                  background: 'var(--amber-d)',
                  border: '1px solid var(--amber-b)',
                  borderRadius: 4,
                  padding: '2px 7px',
                }}
              >
                {permShort(p)}
              </span>
            ))}
          </div>
        </div>
      )}

      <div style={{ fontSize: 11, color: 'var(--t3)', fontFamily: 'JetBrains Mono, monospace', marginTop: 6 }}>
        Total declared permissions: <strong style={{ color: 'var(--t2)' }}>{total_permissions}</strong>
      </div>
    </div>
  )
}
