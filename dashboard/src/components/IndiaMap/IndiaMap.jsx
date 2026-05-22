import { useEffect, useRef, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet'
import 'leaflet/dist/leaflet.css'
import L from 'leaflet'
import { threatLatLng, INDIA_CENTER_LNG, INDIA_CENTER_LAT } from '../../utils/geoHelpers'
import { threatPlaceLabel, threatCoordLabel, VERDICT } from '../../utils/formatters'

const getCustomIcon = (threat, pulsing, selected) => {
  const color = VERDICT.color[threat.verdict] || 'var(--t3)'
  const size = selected || pulsing ? 20 : 10
  const zIndex = selected || pulsing ? 1000 : 1

  const html = `
    <div style="position: relative; width: ${size}px; height: ${size}px; transform: translate(-50%, -50%); z-index: ${zIndex};">
      ${pulsing ? `<div style="position: absolute; inset: -12px; border-radius: 50%; border: 2.5px solid ${color}; animation: threat-ring 1.2s ease-out infinite;"></div>` : ''}
      <div style="width: 100%; height: 100%; border-radius: 50%; background: ${color}; box-shadow: ${selected ? `0 0 16px 4px ${color}` : `0 0 6px 1px ${color}`}; transition: all 0.2s;"></div>
    </div>
  `
  return L.divIcon({
    className: 'custom-leaflet-icon',
    html,
    iconSize: [0, 0],
    iconAnchor: [0, 0],
  })
}

function MapController({ pulseThreat, selectedThreat }) {
  const map = useMap()

  useEffect(() => {
    if (pulseThreat) {
      const [lat, lng] = threatLatLng(pulseThreat)
      map.flyTo([lat, lng], 13, { duration: 2.2, easeLinearity: 0.25 })
    }
  }, [pulseThreat, map])

  useEffect(() => {
    if (pulseThreat?.id) return
    if (selectedThreat) {
      const [lat, lng] = threatLatLng(selectedThreat)
      map.flyTo([lat, lng], 11, { duration: 1.5 })
    }
  }, [selectedThreat, pulseThreat, map])

  return null
}

export default function IndiaMap({ threats, selectedThreat, pulseThreat, onThreatSelect }) {
  const mapRef = useRef(null)

  const resetView = () => {
    if (mapRef.current) {
      mapRef.current.flyTo([INDIA_CENTER_LAT, INDIA_CENTER_LNG], 4.5, { duration: 1.2 })
    }
  }

  const place = pulseThreat ? threatPlaceLabel(pulseThreat) : null
  const coords = pulseThreat ? threatCoordLabel(pulseThreat) : null
  const pulseColor = pulseThreat ? VERDICT.color[pulseThreat.verdict] || 'var(--red)' : 'var(--red)'

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', background: 'var(--map-ocean)' }}>
      <button
        type="button"
        onClick={resetView}
        style={{
          position: 'absolute',
          top: 16,
          left: 16,
          zIndex: 1000,
          background: 'var(--bar-bg)',
          border: '1px solid var(--b1)',
          color: 'var(--t2)',
          borderRadius: 8,
          padding: '7px 14px',
          cursor: 'pointer',
          fontSize: 12,
          fontFamily: 'JetBrains Mono, monospace',
          boxShadow: '0 2px 12px rgba(15,23,42,0.08)',
          transition: 'all 0.2s',
        }}
        onMouseEnter={(e) => {
          e.target.style.background = 'var(--bg2)'
          e.target.style.color = 'var(--t1)'
        }}
        onMouseLeave={(e) => {
          e.target.style.background = 'var(--bar-bg)'
          e.target.style.color = 'var(--t2)'
        }}
      >
        Overview
      </button>

      <MapContainer
        center={[INDIA_CENTER_LAT, INDIA_CENTER_LNG]}
        zoom={4.5}
        zoomControl={false}
        style={{ width: '100%', height: '100%', zIndex: 1 }}
        ref={mapRef}
      >
        {}
        <TileLayer
          url="https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}"
          attribution="&copy; Google Maps"
        />

        <MapController pulseThreat={pulseThreat} selectedThreat={selectedThreat} />

        {threats.map((t) => {
          const [lat, lng] = threatLatLng(t)
          const pulsing = pulseThreat?.id === t.id
          const selected = selectedThreat?.id === t.id
          return (
            <Marker
              key={t.id}
              position={[lat, lng]}
              icon={getCustomIcon(t, pulsing, selected)}
              eventHandlers={{
                click: () => onThreatSelect(t)
              }}
            />
          )
        })}
      </MapContainer>

      <AnimatePresence>
        {pulseThreat && (
          <motion.div
            key={pulseThreat.id}
            initial={{ opacity: 0, y: 16, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.98 }}
            transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
            style={{
              position: 'absolute',
              left: '50%',
              bottom: 28,
              transform: 'translateX(-50%)',
              zIndex: 1000,
              minWidth: 280,
              maxWidth: 'min(92vw, 480px)',
              background: 'var(--bar-bg)',
              border: `1.5px solid ${pulseColor}`,
              borderRadius: 12,
              padding: '14px 18px',
              boxShadow: `0 12px 40px rgba(15,23,42,0.12), 0 0 0 1px rgba(255,255,255,0.8) inset`,
              pointerEvents: 'none',
              backdropFilter: 'blur(8px)',
              WebkitBackdropFilter: 'blur(8px)',
            }}
          >
            <div
              style={{
                fontSize: 9,
                fontFamily: 'JetBrains Mono, monospace',
                letterSpacing: 3,
                color: 'var(--t3)',
                marginBottom: 6,
              }}
            >
              LIVE DETECTION
            </div>
            <div style={{ fontSize: 17, fontWeight: 700, color: 'var(--t1)', letterSpacing: -0.3, lineHeight: 1.35 }}>
              {place || coords || 'Origin not geotagged — enable location on mobile scanner'}
            </div>
            {place && coords && (
              <div style={{ marginTop: 8, fontSize: 11, fontFamily: 'JetBrains Mono, monospace', color: 'var(--t2)' }}>{coords}</div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
