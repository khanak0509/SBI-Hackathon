import { useState, useEffect, useCallback } from 'react'
import { api } from '../api/client'
import { geocodeLocation, CITY_CENTROIDS } from '../utils/geoHelpers'

async function enrichThreats(threatsList) {
  const enriched = [...threatsList]

  for (const t of enriched) {
    if (t.device_lat == null || t.device_lat === 0) {
      const city = t.device_city || t.device_district
      if (city) {

        const cityKey = Object.keys(CITY_CENTROIDS).find(c => String(city).toLowerCase().includes(c.toLowerCase()))
        if (!cityKey) {
          const res = await geocodeLocation(city, t.device_state)
          if (res) {
            t._geocoded_lat = res[0]
            t._geocoded_lng = res[1]
          }
        }
      }
    }
  }
  return enriched
}

export function useThreats() {
  const [threats, setThreats] = useState([])
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    try {
      const [t, s] = await Promise.all([api.getThreats({ limit: 200 }), api.getStats()])
      let items = t.items || []

      enrichThreats(items).then((enriched) => setThreats([...enriched]))

      setThreats(items)
      setStats(s)
    } catch {

    }
    setLoading(false)
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const merge = useCallback((live) => {

    enrichThreats(live).then((enrichedLive) => {
      setThreats((prev) => {
        const ids = new Set(prev.map((t) => t.id))
        return [...enrichedLive.filter((t) => !ids.has(t.id)), ...prev].slice(0, 400)
      })
    })

    setStats((s) =>
      s
        ? {
            ...s,
            total_threats_24h: (s.total_threats_24h || 0) + live.length,
            total_threats_all: (s.total_threats_all || 0) + live.length,
          }
        : s
    )
  }, [])

  return { threats, stats, loading, merge, reload: load }
}
