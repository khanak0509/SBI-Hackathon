import { useState, useEffect } from 'react'

function Clock() {
  const [time, setTime] = useState(new Date())
  useEffect(() => {
    const t = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(t)
  }, [])
  const pad = (n) => String(n).padStart(2, '0')
  return (
    <span style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: 13, color: 'var(--t3)' }}>
      {pad(time.getHours())}:{pad(time.getMinutes())}:{pad(time.getSeconds())} IST
    </span>
  )
}

export default function StatsBar({ stats, connected }) {
  return (
    <div
      style={{
        height: 'var(--bar-h)',
        background: 'var(--bar-bg)',
        borderBottom: '1px solid var(--b1)',
        backdropFilter: 'blur(20px)',
        boxShadow: '0 1px 0 rgba(255,255,255,0.9) inset',
        display: 'flex',
        alignItems: 'center',
        padding: '0 24px',
        gap: 20,
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        zIndex: 100,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
        <span style={{ fontFamily: 'Bebas Neue, sans-serif', fontSize: 26, letterSpacing: 4, color: 'var(--gold)' }}>
          KAVACH
        </span>
        <div style={{ width: 1, height: 22, background: 'var(--b2)' }} />
        <div>
          <div
            style={{
              fontSize: 10,
              fontFamily: 'JetBrains Mono, monospace',
              letterSpacing: 3,
              color: 'var(--t2)',
              fontWeight: 700,
            }}
          >
            FRAUDOPS
          </div>
          <div style={{ fontSize: 9, fontFamily: 'JetBrains Mono, monospace', letterSpacing: 2, color: 'var(--t3)' }}>
            INTELLIGENCE CENTER
          </div>
        </div>
      </div>

      <div style={{ flex: 1, display: 'flex', justifyContent: 'center', gap: 8 }}>
        {[
          { label: '● LIVE', color: 'var(--red)', blink: true, mono: true },
          { label: `${stats?.total_threats_24h ?? '—'} threats / 24h`, color: 'var(--t1)', blink: false, mono: false },
          { label: `${stats?.by_type?.apk ?? '—'} APK`, color: 'var(--t2)', blink: false, mono: false },
          { label: `${stats?.by_type?.url ?? '—'} URL`, color: 'var(--t2)', blink: false, mono: false },
        ].map((item, i) => (
          <div
            key={i}
            style={{
              padding: '4px 14px',
              background: 'var(--s1)',
              border: '1px solid var(--b1)',
              borderRadius: 6,
              fontSize: 13,
              color: item.color,
              fontFamily: item.mono ? 'JetBrains Mono, monospace' : 'Outfit, sans-serif',
              animation: item.blink ? 'blink 1.5s infinite' : 'none',
              fontWeight: item.blink ? 700 : 500,
            }}
          >
            {item.label}
          </div>
        ))}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 14, flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <div
            style={{
              width: 7,
              height: 7,
              borderRadius: '50%',
              background: connected ? 'var(--green)' : 'var(--red)',
              boxShadow: `0 0 6px ${connected ? 'var(--green)' : 'var(--red)'}`,
            }}
          />
          <span
            style={{
              fontSize: 10,
              fontFamily: 'JetBrains Mono, monospace',
              letterSpacing: 2,
              color: connected ? 'var(--green)' : 'var(--red)',
              fontWeight: 600,
            }}
          >
            {connected ? 'CONNECTED' : 'RECONNECTING'}
          </span>
        </div>
        <div style={{ width: 1, height: 16, background: 'var(--b1)' }} />
        <Clock />
      </div>
    </div>
  )
}
