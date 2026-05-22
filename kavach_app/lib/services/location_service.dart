import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceLocationSnapshot {
  DeviceLocationSnapshot({
    required this.lat,
    required this.lng,
    this.city,
    this.district,
    this.state,
    this.accuracyMeters,
    this.timestamp,
  });

  final double lat;
  final double lng;
  final String? city;
  final String? district;
  final String? state;
  final double? accuracyMeters;
  final DateTime? timestamp;

  Map<String, dynamic> toScanFields() => {
        'device_lat': lat,
        'device_lng': lng,
        if (city != null && city!.isNotEmpty) 'device_city': city,
        if (district != null && district!.isNotEmpty) 'device_district': district,
        if (state != null && state!.isNotEmpty) 'device_state': state,
      };
}

class LocationAccess {
  const LocationAccess({
    required this.granted,
    this.serviceEnabled = true,
    this.permanentlyDenied = false,
  });

  final bool granted;
  final bool serviceEnabled;
  final bool permanentlyDenied;

  static const ok = LocationAccess(granted: true);
}

String? _nonEmpty(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Request permission and verify GPS / location services are on.
Future<LocationAccess> ensureLocationAccess({bool request = true}) async {
  final serviceOn = await Geolocator.isLocationServiceEnabled();
  if (!serviceOn) {
    return const LocationAccess(granted: false, serviceEnabled: false);
  }

  var perm = await Permission.locationWhenInUse.status;
  if (!perm.isGranted && request) {
    perm = await Permission.locationWhenInUse.request();
  }
  if (perm.isGranted) return LocationAccess.ok;

  if (perm.isPermanentlyDenied) {
    return const LocationAccess(granted: false, permanentlyDenied: true);
  }

  // Fallback for platforms / edge cases
  var geoPerm = await Geolocator.checkPermission();
  if (geoPerm == LocationPermission.denied && request) {
    geoPerm = await Geolocator.requestPermission();
  }
  if (geoPerm == LocationPermission.deniedForever) {
    return const LocationAccess(granted: false, permanentlyDenied: true);
  }
  if (geoPerm == LocationPermission.denied) {
    return const LocationAccess(granted: false);
  }

  return LocationAccess.ok;
}

Future<DeviceLocationSnapshot?> _snapshotFromPosition(Position pos, {bool geocode = true}) async {
  String? city;
  String? district;
  String? state;

  if (geocode) {
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(
        const Duration(seconds: 8),
      );
      if (marks.isNotEmpty) {
        final p = marks.first;
        city = _nonEmpty(p.locality) ??
            _nonEmpty(p.subAdministrativeArea) ??
            _nonEmpty(p.administrativeArea);
        district = _nonEmpty(p.subLocality) ?? _nonEmpty(p.thoroughfare) ?? _nonEmpty(p.name);
        state = _nonEmpty(p.administrativeArea);
        if (state != null && state == city) {
          state = _nonEmpty(p.administrativeArea);
        }
      }
    } catch (e) {
      debugPrint('KAVACH_DEBUG: reverse geocode failed: $e');
    }
  }

  return DeviceLocationSnapshot(
    lat: pos.latitude,
    lng: pos.longitude,
    city: city,
    district: district,
    state: state,
    accuracyMeters: pos.accuracy,
    timestamp: pos.timestamp,
  );
}

/// One-shot live GPS fix (used before scans and on app start).
Future<DeviceLocationSnapshot?> captureDeviceLocation({bool requestPermission = true}) async {
  final access = await ensureLocationAccess(request: requestPermission);
  if (!access.granted) return null;

  Position? pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } catch (e) {
    debugPrint('KAVACH_DEBUG: getCurrentPosition failed: $e');
    pos = await Geolocator.getLastKnownPosition();
  }

  if (pos == null) return null;
  return _snapshotFromPosition(pos, geocode: true);
}

DateTime? _lastGeocodeAt;
double? _lastGeocodeLat;
double? _lastGeocodeLng;

bool _shouldGeocodeAgain(double lat, double lng) {
  if (_lastGeocodeAt == null || _lastGeocodeLat == null || _lastGeocodeLng == null) return true;
  if (DateTime.now().difference(_lastGeocodeAt!) > const Duration(minutes: 5)) return true;
  const metersPerDeg = 111320.0;
  final dLat = (lat - _lastGeocodeLat!) * metersPerDeg;
  final dLng = (lng - _lastGeocodeLng!) * math.cos(lat * math.pi / 180) * metersPerDeg;
  return (dLat * dLat + dLng * dLng) > 250 * 250;
}

/// Keeps [device_lat]/[device_lng] fresh while the app is open (live location).
StreamSubscription<Position>? watchDeviceLocation(
  void Function(DeviceLocationSnapshot snap) onUpdate, {
  int distanceFilterMeters = 15,
}) {
  StreamSubscription<Position>? sub;
  sub = Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    ),
  ).listen((pos) async {
    final geocode = _shouldGeocodeAgain(pos.latitude, pos.longitude);
    final snap = await _snapshotFromPosition(pos, geocode: geocode);
    if (snap == null) return;
    if (geocode) {
      _lastGeocodeAt = DateTime.now();
      _lastGeocodeLat = pos.latitude;
      _lastGeocodeLng = pos.longitude;
    }
    onUpdate(snap);
  }, onError: (e) {
    debugPrint('KAVACH_DEBUG: position stream error: $e');
  });
  return sub;
}
