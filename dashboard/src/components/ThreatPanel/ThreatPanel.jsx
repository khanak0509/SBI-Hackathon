import { useState, useMemo } from 'react'
import { motion } from 'framer-motion'
import { VERDICT, CHANNEL, timeAgo, shortHash, threatPlaceLabel } from '../../utils/formatters'
import ConfidenceMeter from './ConfidenceMeter'
import BehaviorAnalysis from './BehaviorAnalysis'
import ReportModal from './ReportModal'
import { api } from '../../api/client'

const Divider = () => <div style={{ height: 1, background: 'var(--b1)', margin: '2px 0' }} />

const Row = ({ label, value, mono, color }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '9px 0', alignItems: 'flex-start' }}>
    <span style={{ fontSize: 12, color: 'var(--t3)', flexShrink: 0, marginRight: 12 }}>{label}</span>
    <span
      style={{
        fontSize: 12,
        fontFamily: mono ? 'JetBrains Mono, monospace' : 'Outfit, sans-serif',
        color: color || 'var(--t1)',
        fontWeight: 500,
        textAlign: 'right',
        wordBreak: 'break-all',
        maxWidth: '65%',
      }}
    >
      {value || '—'}
    </span>
  </div>
)

export default function ThreatPanel({ threat, onClose }) {
  const [reports, setReports] = useState(null)
  const [loadingRep, setLoadingRep] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [marked, setMarked] = useState(false)

  const color = VERDICT.color[threat.verdict] || 'var(--t3)'
  const label = VERDICT.label[threat.verdict] || threat.verdict?.toUpperCase()

  const behaviorPayload = useMemo(() => {
    if (threat.behavior_analysis && typeof threat.behavior_analysis === 'object') return threat.behavior_analysis
    return {
      risk_level: threat.behavior_risk_level || 'LOW',
      behavior_risk_score: threat.behavior_risk_score ?? 0,
      dangerous_combos_detected: [],
      high_risk_permissions:
        threat.apk_permissions?.filter((p) =>
          ['BIND_ACCESSIBILITY_SERVICE', 'BIND_DEVICE_ADMIN'].some((r) => p.includes(r))
        ) || [],
      total_permissions: threat.apk_permissions?.length || 0,
    }
  }, [threat])

  const generateReports = async () => {
    setLoadingRep(true)
    try {
      const data = await api.allReports(threat.id)
      setReports(data)
      setShowModal(true)
    } catch {
      /* ignore */
    }
    setLoadingRep(false)
  }

  const markReported = async () => {
    try {
      await api.markReported(threat.id, { certin: true, google: true, cybercrime: false })
      setMarked(true)
    } catch {
      /* ignore */
    }
  }

  return (
    <>
      <motion.div
        initial={{ x: 420, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        exit={{ x: 420, opacity: 0 }}
        transition={{ duration: 0.32, ease: [0.16, 1, 0.3, 1] }}
        style={{
          width: 'var(--panel-w)',
          flexShrink: 0,
          background: 'var(--bg2)',
          borderLeft: '1px solid var(--b1)',
          display: 'flex',
          flexDirection: 'column',
          height: '100%',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            padding: '14px 18px',
            borderBottom: '1px solid var(--b1)',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexShrink: 0,
            background: 'var(--bg3)',
          }}
        >
          <div style={{ flex: 1 }}>
            <div
              style={{
                fontSize: 10,
                fontFamily: 'JetBrains Mono, monospace',
                letterSpacing: 2,
                color: 'var(--t3)',
                marginBottom: 2,
              }}
            >
              THREAT ID
            </div>
            <div style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: 'var(--t2)' }}>{shortHash(threat.id)}</div>
          </div>
          <span
            style={{
              fontSize: 11,
              fontWeight: 700,
              padding: '4px 12px',
              borderRadius: 5,
              background: VERDICT.dim[threat.verdict],
              border: `1px solid ${VERDICT.border[threat.verdict]}`,
              color,
            }}
          >
            {label}
          </span>
          <button
            type="button"
            onClick={onClose}
            style={{
              background: 'var(--s1)',
              border: '1px solid var(--b1)',
              borderRadius: 6,
              width: 28,
              height: 28,
              cursor: 'pointer',
              color: 'var(--t3)',
              fontSize: 14,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            ✕
          </button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px' }}>
          <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
            {[
              { label: 'DETECTED', val: timeAgo(threat.created_at) },
              { label: 'LOCATION', val: threatPlaceLabel(threat) || '—' },
            ].map((item) => (
              <div
                key={item.label}
                style={{
                  flex: 1,
                  background: 'var(--s1)',
                  border: '1px solid var(--b1)',
                  borderRadius: 8,
                  padding: '10px 12px',
                }}
              >
                <div
                  style={{
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono, monospace',
                    letterSpacing: 2,
                    color: 'var(--t3)',
                    marginBottom: 4,
                  }}
                >
                  {item.label}
                </div>
                <div style={{ fontSize: 13, color: 'var(--t1)', fontWeight: 500 }}>{item.val}</div>
              </div>
            ))}
          </div>

          <div
            style={{
              background: 'var(--s1)',
              border: '1px solid var(--b1)',
              borderRadius: 8,
              padding: '12px 14px',
              marginBottom: 14,
            }}
          >
            <ConfidenceMeter confidence={threat.confidence} verdict={threat.verdict} />
          </div>

          {threat.threat_type === 'apk' && (
            <div
              style={{
                background: 'var(--s1)',
                border: '1px solid var(--b1)',
                borderRadius: 8,
                padding: '12px 14px',
                marginBottom: 14,
              }}
            >
              <div
                style={{
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono, monospace',
                  letterSpacing: 2,
                  color: 'var(--t2)',
                  fontWeight: 700,
                  marginBottom: 12,
                }}
              >
                APK DETAILS
              </div>
              <Row label="Package" value={threat.apk_package_name} mono />
              <Divider />
              <Row label="APK file SHA-256" value={shortHash(threat.apk_sha256)} mono />
              <Divider />
              {threat.apk_cert_sha256 && (
                <>
                  <Row label="Signing cert SHA-256" value={shortHash(threat.apk_cert_sha256)} mono />
                  <Divider />
                </>
              )}
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '9px 0', alignItems: 'center' }}>
                <span style={{ fontSize: 13, color: 'var(--t3)' }}>Certificate</span>
                <span
                  style={{
                    fontSize: 12,
                    fontWeight: 700,
                    color: threat.cert_is_official ? 'var(--green)' : 'var(--red)',
                    background: threat.cert_is_official ? 'var(--green-d)' : 'var(--red-d)',
                    border: `1px solid ${threat.cert_is_official ? 'var(--green-b)' : 'var(--red-b)'}`,
                    borderRadius: 5,
                    padding: '3px 10px',
                  }}
                >
                  {threat.cert_is_official ? '✓ Official SBI Cert' : '✗ Certificate Mismatch'}
                </span>
              </div>
              <Divider />
              <Row label="Source" value={CHANNEL[threat.source_channel] || threat.source_channel} />
            </div>
          )}

          {threat.threat_type === 'url' && (
            <div
              style={{
                background: 'var(--s1)',
                border: '1px solid var(--b1)',
                borderRadius: 8,
                padding: '12px 14px',
                marginBottom: 14,
              }}
            >
              <div
                style={{
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono, monospace',
                  letterSpacing: 2,
                  color: 'var(--t2)',
                  fontWeight: 700,
                  marginBottom: 12,
                }}
              >
                URL DETAILS
              </div>
              <div
                style={{
                  background: 'var(--code-bg)',
                  borderRadius: 6,
                  padding: '10px 12px',
                  marginBottom: 12,
                  fontFamily: 'JetBrains Mono, monospace',
                  fontSize: 13,
                  color: 'var(--t1)',
                  fontWeight: 500,
                  wordBreak: 'break-all',
                  userSelect: 'text',
                  lineHeight: 1.6,
                }}
              >
                {threat.raw_input}
              </div>
              {threat.url_features &&
                Object.entries(threat.url_features).map(([k, v]) => {
                  const risky = ['suspicious_tld', 'has_ip_address', 'has_at_symbol', 'has_sbi_keyword', 'has_port'].includes(k)
                  const good = k === 'uses_https'
                  return (
                    <div
                      key={k}
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        padding: '7px 0',
                        borderBottom: '1px solid var(--b1)',
                      }}
                    >
                      <span style={{ fontSize: 12, fontFamily: 'JetBrains Mono, monospace', color: 'var(--t3)' }}>{k}</span>
                      <span
                        style={{
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono, monospace',
                          color: risky && v === 1 ? 'var(--red)' : good && v === 1 ? 'var(--green)' : 'var(--t2)',
                          fontWeight: (risky && v === 1) || (good && v === 1) ? 700 : 400,
                        }}
                      >
                        {String(v)}
                      </span>
                    </div>
                  )
                })}
            </div>
          )}

          {threat.threat_type === 'apk' && (threat.behavior_risk_level || threat.behavior_analysis) && (
            <div style={{ marginBottom: 14 }}>
              <BehaviorAnalysis behavior={behaviorPayload} />
            </div>
          )}
        </div>

        <div
          style={{
            padding: '12px 18px',
            borderTop: '1px solid var(--b1)',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 8,
            flexShrink: 0,
            background: 'var(--bg3)',
          }}
        >
          <button
            type="button"
            onClick={generateReports}
            disabled={loadingRep}
            style={{
              padding: '11px 0',
              background: 'var(--gold-d)',
              border: '1px solid var(--gold-b)',
              borderRadius: 8,
              color: 'var(--gold)',
              cursor: 'pointer',
              fontSize: 13,
              fontWeight: 600,
              opacity: loadingRep ? 0.6 : 1,
            }}
          >
            {loadingRep ? 'Loading...' : 'Generate Reports ↗'}
          </button>
          <button
            type="button"
            onClick={markReported}
            disabled={marked}
            style={{
              padding: '11px 0',
              background: marked ? 'var(--green-d)' : 'var(--s2)',
              border: `1px solid ${marked ? 'var(--green-b)' : 'var(--b1)'}`,
              borderRadius: 8,
              color: marked ? 'var(--green)' : 'var(--t2)',
              cursor: marked ? 'default' : 'pointer',
              fontSize: 13,
              fontWeight: 500,
            }}
          >
            {marked ? '✓ Reported' : 'Mark Reported'}
          </button>
        </div>
      </motion.div>

      {showModal && reports && <ReportModal reports={reports} threatId={threat.id} onClose={() => setShowModal(false)} />}
    </>
  )
}
