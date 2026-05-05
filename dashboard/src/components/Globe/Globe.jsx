import { useRef, useEffect, useMemo } from 'react'
import { Canvas, useFrame, useLoader } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import * as THREE from 'three'
import gsap from 'gsap'
import { vertexShader, fragmentShader } from './AtmosphereShader'
import { latLngToXYZ, threatLatLng } from '../../utils/geoHelpers'
import { VERDICT } from '../../utils/formatters'

function Stars() {
  const geo = useMemo(() => {
    const g = new THREE.BufferGeometry()
    const verts = new Float32Array(3000 * 3)
    for (let i = 0; i < 3000; i++) {
      const theta = Math.random() * Math.PI * 2
      const phi = Math.acos(2 * Math.random() - 1)
      const r = 80 + Math.random() * 20
      verts[i * 3] = r * Math.sin(phi) * Math.cos(theta)
      verts[i * 3 + 1] = r * Math.cos(phi)
      verts[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta)
    }
    g.setAttribute('position', new THREE.BufferAttribute(verts, 3))
    return g
  }, [])
  return (
    <points geometry={geo}>
      <pointsMaterial size={0.18} color="#ffffff" transparent opacity={0.55} sizeAttenuation />
    </points>
  )
}

function Atmosphere() {
  return (
    <mesh scale={[1.06, 1.06, 1.06]}>
      <sphereGeometry args={[1.5, 64, 64]} />
      <shaderMaterial
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        side={THREE.BackSide}
        blending={THREE.AdditiveBlending}
        transparent
      />
    </mesh>
  )
}

function Earth({ earthRef, rotationPausedRef }) {
  const texture = useLoader(
    THREE.TextureLoader,
    'https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/textures/planets/earth_atmos_2048.jpg'
  )
  useFrame(() => {
    if (!rotationPausedRef?.current && earthRef.current) earthRef.current.rotation.y += 0.0006
  })
  return (
    <mesh ref={earthRef}>
      <sphereGeometry args={[1.5, 64, 64]} />
      <meshPhongMaterial map={texture} />
    </mesh>
  )
}

function ThreatMarker({ threat, onClick }) {
  const ref = useRef()
  const ring = useRef()
  const [lat, lng] = threatLatLng(threat)
  const pos = latLngToXYZ(lat, lng, 1.52)
  const threeColor = VERDICT.hex[threat.verdict] || '#7b78a8'

  useFrame(({ clock }) => {
    if (ref.current) {
      const s = 0.9 + 0.3 * Math.abs(Math.sin(clock.elapsedTime * 2.5 + lat))
      ref.current.scale.setScalar(s)
    }
    if (ring.current) {
      ring.current.scale.setScalar(1 + 1.5 * ((clock.elapsedTime * 0.8) % 1))
      ring.current.material.opacity = Math.max(0, 1 - ((clock.elapsedTime * 0.8) % 1))
    }
  })

  return (
    <group position={[pos.x, pos.y, pos.z]}>
      <mesh ref={ring}>
        <torusGeometry args={[0.025, 0.004, 8, 32]} />
        <meshBasicMaterial color={threeColor} transparent opacity={0.8} />
      </mesh>
      <mesh
        ref={ref}
        onClick={(e) => {
          e.stopPropagation()
          onClick(threat)
        }}
      >
        <sphereGeometry args={[0.018, 12, 12]} />
        <meshBasicMaterial color={threeColor} />
      </mesh>
      <mesh position={[0, -0.025, 0]}>
        <cylinderGeometry args={[0.002, 0.002, 0.05, 4]} />
        <meshBasicMaterial color={threeColor} transparent opacity={0.5} />
      </mesh>
    </group>
  )
}

function Scene({ threats, onThreatClick, focusedLng }) {
  const earthRef = useRef()
  const rotationPausedRef = useRef(false)

  useEffect(() => {
    if (focusedLng == null || !earthRef.current) return
    rotationPausedRef.current = true
    const targetY = -(focusedLng * Math.PI) / 180
    gsap.to(earthRef.current.rotation, {
      y: targetY,
      duration: 1.4,
      ease: 'power2.inOut',
      onComplete: () => {
        rotationPausedRef.current = false
      },
    })
  }, [focusedLng])

  return (
    <>
      <ambientLight intensity={0.45} />
      <directionalLight position={[5, 3, 5]} intensity={1.3} />
      <Stars />
      <Atmosphere />
      <Earth earthRef={earthRef} rotationPausedRef={rotationPausedRef} />
      {threats.map((t) => (
        <ThreatMarker key={t.id} threat={t} onClick={onThreatClick} />
      ))}
      <OrbitControls
        enableDamping
        dampingFactor={0.08}
        enableZoom={false}
        enablePan={false}
        autoRotate={false}
        minPolarAngle={Math.PI * 0.2}
        maxPolarAngle={Math.PI * 0.8}
      />
    </>
  )
}

export default function Globe({ threats, onThreatClick, focusedThreat }) {
  const focusedLng = focusedThreat ? threatLatLng(focusedThreat)[1] : null

  return (
    <div style={{ width: '100%', height: '100%', background: '#04050f' }}>
      <Canvas camera={{ position: [0, 0, 3.8], fov: 45 }}>
        <Scene threats={threats} onThreatClick={onThreatClick} focusedLng={focusedLng} />
      </Canvas>
    </div>
  )
}
