import { useState } from 'react'
import ThreatFeedCard from './ThreatFeedCard'

const FILTERS = ['ALL', 'APK', 'URL']

export default function ThreatFeed({ threats, selectedThreat, onSelect }) {
  const [filter, setFilter] = useState('ALL')

  const filtered = threats
    .filter((t) => {
      if (filter === 'APK') return t.threat_type === 'apk'
      if (filter === 'URL') return t.threat_type === 'url'
      return true
    })
    .slice(0, 100)

  return (
    <div
      style={{
        width: 'var(--feed-w)',
        flexShrink: 0,
        borderRight: '1px solid var(--b1)',
        background: 'var(--bg2)',
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          padding: '13px 16px',
          borderBottom: '1px solid var(--b1)',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          flexShrink: 0,
          background: 'var(--bg3)',
        }}
      >
        <div
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: 'var(--red)',
            animation: 'blink 1s infinite',
            boxShadow: '0 0 6px var(--red)',
          }}
        />
        <span
          style={{
            fontSize: 11,
            fontFamily: 'JetBrains Mono, monospace',
            letterSpacing: 3,
            color: 'var(--t2)',
            fontWeight: 700,
          }}
        >
          LIVE FEED
        </span>
        <div style={{ flex: 1 }} />
        <span
          style={{
            fontSize: 11,
            fontFamily: 'JetBrains Mono, monospace',
            background: 'var(--s2)',
            border: '1px solid var(--b1)',
            borderRadius: 5,
            padding: '2px 8px',
            color: 'var(--t2)',
            fontWeight: 600,
          }}
        >
          {filtered.length}
        </span>
      </div>

      <div
        style={{
          padding: '8px 12px',
          borderBottom: '1px solid var(--b1)',
          display: 'flex',
          gap: 6,
          flexShrink: 0,
          background: 'var(--bg2)',
        }}
      >
        {FILTERS.map((f) => (
          <button
            type="button"
            key={f}
            onClick={() => setFilter(f)}
            style={{
              padding: '4px 12px',
              borderRadius: 5,
              fontSize: 11,
              fontWeight: 700,
              fontFamily: 'JetBrains Mono, monospace',
              border: filter === f ? '1px solid var(--gold-b)' : '1px solid var(--b1)',
              background: filter === f ? 'var(--gold-d)' : 'transparent',
              color: filter === f ? 'var(--gold)' : 'var(--t3)',
              cursor: 'pointer',
              transition: 'all 0.15s',
            }}
          >
            {f}
          </button>
        ))}
      </div>

      <div style={{ flex: 1, overflowY: 'auto' }}>
        {filtered.length === 0 ? (
          <div
            style={{
              padding: 28,
              textAlign: 'center',
              color: 'var(--t3)',
              fontSize: 13,
              fontFamily: 'JetBrains Mono, monospace',
            }}
          >
            Waiting for threats...
          </div>
        ) : (
          filtered.map((t) => (
            <ThreatFeedCard key={t.id} threat={t} selected={selectedThreat?.id === t.id} onClick={() => onSelect(t)} />
          ))
        )}
      </div>
    </div>
  )
}
