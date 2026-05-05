export const vertexShader = `
  varying vec3 vNormal;
  void main() {
    vNormal = normalize(normalMatrix * normal);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`
export const fragmentShader = `
  varying vec3 vNormal;
  void main() {
    float i = pow(0.55 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 3.5);
    gl_FragColor = vec4(0.1, 0.3, 1.0, 1.0) * i * 1.8;
  }
`
