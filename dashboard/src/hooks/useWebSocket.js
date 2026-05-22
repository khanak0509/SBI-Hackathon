import { useEffect, useRef, useState, useCallback } from 'react'

export function useWebSocket(url) {
  const ws = useRef(null)
  const retry = useRef(null)
  const [connected, setConnected] = useState(false)
  const [liveThreats, setLiveThreats] = useState([])
  const [latestNewThreat, setLatestNewThreat] = useState(null)

  const connect = useCallback(() => {
    try {
      ws.current = new WebSocket(url)
      ws.current.onopen = () => setConnected(true)
      ws.current.onerror = () => ws.current?.close()
      ws.current.onclose = () => {
        setConnected(false)
        retry.current = setTimeout(connect, 3000)
      }
      ws.current.onmessage = ({ data }) => {
        try {
          const msg = JSON.parse(data)
          if (msg.event === 'new_threat' && msg.payload) {
            setLiveThreats((p) => [msg.payload, ...p].slice(0, 300))
            setLatestNewThreat(msg.payload)
          }
        } catch {

        }
      }
    } catch {
      retry.current = setTimeout(connect, 3000)
    }
  }, [url])

  useEffect(() => {
    connect()
    return () => {
      clearTimeout(retry.current)
      ws.current?.close()
    }
  }, [connect])

  return { connected, liveThreats, latestNewThreat }
}
