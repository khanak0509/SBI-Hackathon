import { useState } from 'react'

const TAB_LABELS = { certin: 'CERT-In', google: 'Google Safe Browsing', cybercrime: 'Cybercrime Portal' }

export default function ReportModal({ reports, threatId, onClose }) {
  const [tab, setTab] = useState('certin')
  const report = reports?.[tab]

  const copy = () => {
    navigator.clipboard.writeText(JSON.stringify(report, null, 2))
  }

  const download = () => {
    const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `kavach_${tab}_${threatId?.slice(0, 8)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.75)',
        backdropFilter: 'blur(8px)',
        zIndex: 200,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
      }}
      onClick={onClose}
      role="presentation"
    >
      <div
        style={{
          background: 'var(--bg2)',
          border: '1px solid var(--b1)',
          borderRadius: 16,
          width: '100%',
          maxWidth: 640,
          maxHeight: '80vh',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          boxShadow: '0 24px 64px rgba(0,0,0,0.2)',
        }}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        <div
          style={{
            padding: '16px 22px',
            borderBottom: '1px solid var(--b1)',
            display: 'flex',
            alignItems: 'center',
            background: 'var(--bg3)',
          }}
        >
          <span style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', letterSpacing: 2, color: 'var(--t2)', fontWeight: 700 }}>
            THREAT INTELLIGENCE REPORTS
          </span>
          <div style={{ flex: 1 }} />
          <button
            type="button"
            onClick={onClose}
            style={{
              background: 'var(--s1)',
              border: '1px solid var(--b1)',
              borderRadius: 6,
              width: 28,
              height: 28,
              color: 'var(--t3)',
              cursor: 'pointer',
              fontSize: 14,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            ✕
          </button>
        </div>

        <div style={{ display: 'flex', borderBottom: '1px solid var(--b1)', padding: '0 22px', background: 'var(--bg2)' }}>
          {Object.entries(TAB_LABELS).map(([key, label]) => (
            <button
              type="button"
              key={key}
              onClick={() => setTab(key)}
              style={{
                padding: '11px 14px',
                background: 'none',
                border: 'none',
                borderBottom: tab === key ? '2px solid var(--gold)' : '2px solid transparent',
                color: tab === key ? 'var(--gold)' : 'var(--t3)',
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: tab === key ? 600 : 400,
                transition: 'color 0.15s',
                marginRight: 4,
              }}
            >
              {label}
            </button>
          ))}
        </div>

        <div style={{ flex: 1, overflowY: 'auto', background: 'var(--code-bg)', padding: 18 }}>
          <pre
            style={{
              fontFamily: 'JetBrains Mono, monospace',
              fontSize: 12,
              lineHeight: 1.7,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
              color: 'var(--t1)',
            }}
          >
            {JSON.stringify(report || {}, null, 2)}
          </pre>
        </div>

        <div style={{ padding: '12px 22px', borderTop: '1px solid var(--b1)', display: 'flex', gap: 8, background: 'var(--bg3)' }}>
          <button
            type="button"
            onClick={copy}
            style={{
              padding: '8px 18px',
              background: 'var(--s2)',
              border: '1px solid var(--b1)',
              borderRadius: 8,
              color: 'var(--t1)',
              cursor: 'pointer',
              fontSize: 13,
              fontWeight: 500,
            }}
          >
            Copy JSON
          </button>
          <button
            type="button"
            onClick={download}
            style={{
              padding: '8px 18px',
              background: 'var(--gold-d)',
              border: '1px solid var(--gold-b)',
              borderRadius: 8,
              color: 'var(--gold)',
              cursor: 'pointer',
              fontSize: 13,
              fontWeight: 600,
            }}
          >
            Download .json
          </button>
        </div>
      </div>
    </div>
  )
}
