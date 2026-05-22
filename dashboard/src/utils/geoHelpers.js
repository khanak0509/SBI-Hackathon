export function latLngToXYZ(lat, lng, R = 1.5) {
  const phi = (90 - lat) * (Math.PI / 180)
  const theta = (lng + 180) * (Math.PI / 180)
  return {
    x: -(R * Math.sin(phi) * Math.cos(theta)),
    y: R * Math.cos(phi),
    z: R * Math.sin(phi) * Math.sin(theta),
  }
}

export const INDIA_CENTER_LNG = 78.9629
export const INDIA_CENTER_LAT = 20.5937

export const STATE_CENTROIDS = {
  Maharashtra: [75.71, 19.75],
  Gujarat: [71.19, 22.26],
  Rajasthan: [74.22, 27.02],
  'Uttar Pradesh': [80.95, 26.85],
  Bihar: [85.31, 25.1],
  'West Bengal': [87.85, 22.99],
  'Tamil Nadu': [78.66, 11.13],
  Karnataka: [75.71, 15.32],
  'Andhra Pradesh': [79.74, 15.91],
  Telangana: [79.02, 18.11],
  'Madhya Pradesh': [78.66, 22.97],
  Delhi: [77.1, 28.7],
  Punjab: [75.34, 31.15],
  Haryana: [76.09, 29.06],
  Kerala: [76.27, 10.85],
  Odisha: [85.1, 20.95],
  Jharkhand: [85.28, 23.61],
  Assam: [92.94, 26.2],
  Chhattisgarh: [81.87, 21.28],
  Goa: [74.12, 15.3],
  Uttarakhand: [79.02, 30.32],
  'Himachal Pradesh': [77.58, 31.65],
  'Arunachal Pradesh': [94.73, 27.1],
  Manipur: [93.9, 24.66],
  Meghalaya: [91.37, 25.57],
  Mizoram: [92.94, 23.73],
  Nagaland: [94.12, 26.16],
  Sikkim: [88.61, 27.53],
  Tripura: [91.75, 23.94],
}

export const CITY_CENTROIDS = {
  Jodhpur: [73.0243, 26.2389],
  Mumbai: [72.8777, 19.0760],
  Delhi: [77.2090, 28.6139],
  Bangalore: [77.5946, 12.9716],
  Hyderabad: [78.4867, 17.3850],
  Chennai: [80.2707, 13.0827],
  Kolkata: [88.3639, 22.5726],
  Pune: [73.8567, 18.5204],
  Jaipur: [75.7873, 26.9124],
  Ahmedabad: [72.5714, 23.0225],
}

const geocodeCache = new Map()

export async function geocodeLocation(city, state) {
  const query = `${city ? city + ',' : ''} ${state || ''}, India`.trim()
  if (geocodeCache.has(query)) return geocodeCache.get(query)

  try {
    const res = await fetch(`https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=1`)
    const data = await res.json()
    if (data && data.length > 0) {
      const result = [Number(data[0].lat), Number(data[0].lon)]
      geocodeCache.set(query, result)
      return result
    }
  } catch (err) {
    console.error('Geocoding failed', err)
  }

  geocodeCache.set(query, null)
  return null
}

export function threatLatLng(threat) {
  if (threat._geocoded_lat && threat._geocoded_lng) {
    return [threat._geocoded_lat, threat._geocoded_lng]
  }

  if (threat.device_lat != null && threat.device_lng != null) {
    let lat = Number(threat.device_lat)
    let lng = Number(threat.device_lng)

    if (lat !== 0 || lng !== 0) {

      if (lat > 40 && lng < 40) {
        return [lng, lat]
      }
      return [lat, lng]
    }
  }

  const cityOrDistrict = threat.device_city || threat.device_district
  if (cityOrDistrict) {
    const cityStr = String(cityOrDistrict).trim().toLowerCase()
    const cityKey = Object.keys(CITY_CENTROIDS).find(
      (c) => cityStr.includes(c.toLowerCase())
    )
    if (cityKey) {
      const [lng, lat] = CITY_CENTROIDS[cityKey]
      return [lat, lng]
    }
  }

  if (threat.device_state) {
    const stateStr = String(threat.device_state).trim().toLowerCase()
    const stateKey = Object.keys(STATE_CENTROIDS).find(
      (s) => s.toLowerCase() === stateStr
    )
    if (stateKey) {
      const [lng, lat] = STATE_CENTROIDS[stateKey]
      return [lat, lng]
    }
  }

  return [INDIA_CENTER_LAT, INDIA_CENTER_LNG]
}
