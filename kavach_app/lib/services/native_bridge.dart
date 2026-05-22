import 'dart:async';

import 'package:flutter/services.dart';

class NativeBridge {
  static const _method = MethodChannel('kavach/native');
  static const _packageEvents = EventChannel('kavach/package_threats');

  static Future<String?> getSelfCertHash() async {
    try {
      return await _method.invokeMethod<String>('getSelfCertHash');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> verifyIntegrity(String pinnedHash) async {
    final hash = await getSelfCertHash();
    if (hash == null) return true; 
    return hash.toLowerCase() == pinnedHash.toLowerCase();
  }

  static Future<Map<String, dynamic>?> checkPendingPackageThreat() async {
    try {
      final result = await _method.invokeMethod<Map>('checkPendingThreat');
      if (result == null) return null;
      final pkg = result['package_name'] as String?;
      if (pkg == null || pkg.isEmpty) return null;
      return {
        'package_name': pkg,
        'similarity': result['similarity'] ?? 0.8,
        'verdict': 'fake_apk',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPendingPackageThreat() async {
    try {
      await _method.invokeMethod('clearPendingThreat');
    } catch (_) {}
  }

  static Stream<Map<String, dynamic>> get packageThreatStream =>
      _packageEvents
          .receiveBroadcastStream()
          .map((e) => Map<String, dynamic>.from(e as Map));

  static Future<void> openAppSettings(String packageName) async {
    try {
      await _method.invokeMethod('openAppSettings', {'package': packageName});
    } catch (_) {}
  }

  static Future<bool> hasNotificationAccess() async {
    try {
      final result = await _method.invokeMethod<bool>('hasNotificationAccess');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    try {
      await _method.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<void> openAppUninstall(String packageName) async {
    try {
      await _method.invokeMethod('openAppUninstall', {'package': packageName});
    } catch (_) {}
  }
}
