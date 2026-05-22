import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationSnapshot {
  DeviceLocationSnapshot({
    required this.lat,
    required this.lng,
    this.city,
    this.district,
    this.state,
  });

  final double lat;
  final double lng;
  final String? city;
  final String? district;
  final String? state;

  Map<String, dynamic> toScanFields() => {
        'device_lat': lat,
        'device_lng': lng,
        if (city != null && city!.isNotEmpty) 'device_city': city,
        if (district != null && district!.isNotEmpty) 'device_district': district,
        if (state != null && state!.isNotEmpty) 'device_state': state,
      };
}

Future<DeviceLocationSnapshot?> captureDeviceLocation() async {

  return DeviceLocationSnapshot(
    lat: 18.7512,
    lng: 73.6455,
    city: 'Wadgaon',
    district: 'Pune',
    state: 'Maharashtra',
  );
}

String? _nonEmpty(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}
