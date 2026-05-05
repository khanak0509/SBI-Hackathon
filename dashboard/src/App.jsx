import { useState, useEffect, useCallback, useMemo } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import IndiaMap from './components/IndiaMap/IndiaMap'
import ThreatFeed from './components/ThreatFeed/ThreatFeed'
import ThreatPanel from './components/ThreatPanel/ThreatPanel'
import StatsBar from './components/StatsBar/StatsBar'
import { useWebSocket } from './hooks/useWebSocket'
import { useThreats } from './hooks/useThreats'

const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:8000/ws/threats'

export default function App() {
  const { connected, liveThreats, latestNewThreat } = useWebSocket(WS_URL)
  const { threats, stats, merge } = useThreats()
  const [allThreats, setAllThreats] = useState([])
  const [selectedThreat, setSelectedThreat] = useState(null)
  const [mapPulse, setMapPulse] = useState(null)

  useEffect(() => {
    setAllThreats((prev) => {
      const ids = new Set(prev.map((t) => t.id))
      return [...threats.filter((t) => !ids.has(t.id)), ...prev].slice(0, 400)
    })
  }, [threats])

  useEffect(() => {
    if (liveThreats.length === 0) return
    setAllThreats((prev) => {
      const ids = new Set(prev.map((t) => t.id))
      return [...liveThreats.filter((t) => !ids.has(t.id)), ...prev].slice(0, 400)
    })
    merge(liveThreats)
  }, [liveThreats, merge])

  useEffect(() => {
    if (!latestNewThreat?.id) return
    
    const triggerPulse = async () => {
      const t = { ...latestNewThreat }
      if (t.device_lat == null || t.device_lat === 0) {
        const city = t.device_city || t.device_district
        if (city) {
          const { geocodeLocation, CITY_CENTROIDS } = await import('./utils/geoHelpers')
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
      setMapPulse(t)
      setTimeout(() => {
        setMapPulse((prev) => (prev?.id === t.id ? null : prev))
      }, 7000)
    }
    
    triggerPulse()
  }, [latestNewThreat])

  const selectThreat = useCallback((threat) => {
    setSelectedThreat(threat)
  }, [])

  const clearSelection = useCallback(() => {
    setSelectedThreat(null)
  }, [])

  // DEDUPLICATION: Only show the latest threat for each unique app/URL
  const deduplicatedThreats = useMemo(() => {
    const map = new Map()
    // Sort allThreats by date (newest first)
    const sorted = [...allThreats].sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    
    for (const t of sorted) {
      const key = t.threat_type === 'apk' ? (t.apk_package_name || t.raw_input) : t.raw_input
      if (!map.has(key)) {
        map.set(key, t)
      }
    }
    return Array.from(map.values())
  }, [allThreats])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', overflow: 'hidden' }}>
      <StatsBar stats={stats} connected={connected} />

      <div
        style={{
          display: 'flex',
          flex: 1,
          marginTop: 'var(--bar-h)',
          overflow: 'hidden',
        }}
      >
        <ThreatFeed threats={deduplicatedThreats} selectedThreat={selectedThreat} onSelect={selectThreat} />

        <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
          <motion.div
            initial={{ opacity: 0.96 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.35 }}
            style={{ position: 'absolute', inset: 0 }}
          >
            <IndiaMap
              threats={deduplicatedThreats}
              selectedThreat={selectedThreat}
              pulseThreat={mapPulse}
              onThreatSelect={setSelectedThreat}
            />
          </motion.div>
        </div>

        <AnimatePresence>
          {selectedThreat && <ThreatPanel key={selectedThreat.id} threat={selectedThreat} onClose={clearSelection} />}
        </AnimatePresence>
      </div>
    </div>
  )
}
