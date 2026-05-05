const B = import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'

async function g(p) {
  const r = await fetch(`${B}${p}`)
  if (!r.ok) throw new Error(`${p} ${r.status}`)
  return r.json()
}

async function po(p, b) {
  const r = await fetch(`${B}${p}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(b ?? {}),
  })
  if (!r.ok) throw new Error(`${p} ${r.status}`)
  return r.json()
}

export const api = {
  getThreats: (p = {}) => g(`/threats?${new URLSearchParams(p)}`),
  getThreat: (id) => g(`/threats/${id}`),
  getStats: () => g('/threats/stats'),
  allReports: (id) => po(`/reports/${id}/all`, {}),
  markReported: (id, b) => po(`/threats/${id}/mark_reported`, b),
}
