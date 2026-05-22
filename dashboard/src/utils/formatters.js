import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

dayjs.extend(relativeTime)

export const timeAgo = (iso) => dayjs(iso).fromNow()
export const fmtDate = (iso) => dayjs(iso).format('DD MMM YYYY · HH:mm:ss')
export const shortHash = (h) => (h ? `${h.slice(0, 10)}···${h.slice(-6)}` : '—')
export const pct = (v) => `${((v || 0) * 100).toFixed(1)}%`

export const VERDICT = {
  label: { phishing: 'PHISHING URL', fake_apk: 'FAKE APK', review: 'NEEDS REVIEW', safe: 'SAFE' },
  color: { phishing: 'var(--amber)', fake_apk: 'var(--red)', review: 'var(--blue)', safe: 'var(--green)' },
  dim: { phishing: 'var(--amber-d)', fake_apk: 'var(--red-d)', review: 'var(--blue-d)', safe: 'var(--green-d)' },
  border: { phishing: 'var(--amber-b)', fake_apk: 'var(--red-b)', review: 'var(--blue-b)', safe: 'var(--green-b)' },
  hex: { phishing: '#f59e0b', fake_apk: '#e05555', review: '#4a9eff', safe: '#35d073' },
}

export const CHANNEL = {
  device_scan: '📱 Device Scanner',
  whatsapp_bot: '💬 WhatsApp Bot',
  telegram_bot: '🤖 Telegram Bot',
  manual: '🔍 Manual Scan',
  sms: '📨 SMS Link',
}

export function threatPlaceLabel(t) {
  const city = t.device_city || t.device_district
  const state = t.device_state
  if (city && state) return `${city}, ${state}`
  if (state) return state
  if (city) return city
  return null
}

export function threatCoordLabel(t) {
  if (t.device_lat == null || t.device_lng == null) return null
  const la = Number(t.device_lat).toFixed(4)
  const ln = Number(t.device_lng).toFixed(4)
  return `${la}°N, ${ln}°E`
}
