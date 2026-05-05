import 'dart:async';

import 'package:flutter/services.dart';

/// Bridges Kotlin → Flutter for:
///   1. Self-integrity check (cert hash)
///   2. Real-time PACKAGE_ADDED events from KavachPackageReceiver
class NativeBridge {
  static const _method = MethodChannel('kavach/native');
  static const _packageEvents = EventChannel('kavach/package_threats');

  // ── Self-integrity ────────────────────────────────────────────────────────

  /// Returns the running app's own signing-cert SHA-256 via Kotlin.
  static Future<String?> getSelfCertHash() async {
    try {
      return await _method.invokeMethod<String>('getSelfCertHash');
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the app's signing cert matches [pinnedHash].
  /// Returns true on non-Android (so dev runs on macOS/web still work).
  static Future<bool> verifyIntegrity(String pinnedHash) async {
    final hash = await getSelfCertHash();
    if (hash == null) return true; // non-Android platform — skip check
    return hash.toLowerCase() == pinnedHash.toLowerCase();
  }

  // ── Pending package threat (set by KavachPackageReceiver while backgrounded) ──

  /// Returns the package name written by KavachPackageReceiver to SharedPreferences,
  /// or null if there is no pending threat.
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

  /// Clears the pending threat from SharedPreferences after it has been shown.
  static Future<void> clearPendingPackageThreat() async {
    try {
      await _method.invokeMethod('clearPendingThreat');
    } catch (_) {}
  }

  // ── Package threat stream ─────────────────────────────────────────────────

  /// Emits a Map with 'package_name' and 'similarity' whenever
  /// KavachPackageReceiver detects a suspicious app install.
  static Stream<Map<String, dynamic>> get packageThreatStream =>
      _packageEvents
          .receiveBroadcastStream()
          .map((e) => Map<String, dynamic>.from(e as Map));

  // ── Open app settings ─────────────────────────────────────────────────────

  static Future<void> openAppSettings(String packageName) async {
    try {
      await _method.invokeMethod('openAppSettings', {'package': packageName});
    } catch (_) {}
  }

  // ── Notification Access ───────────────────────────────────────────────────

  /// Checks if KAVACH has been granted Notification Listener permission.
  static Future<bool> hasNotificationAccess() async {
    try {
      final result = await _method.invokeMethod<bool>('hasNotificationAccess');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android settings page to grant Notification Listener permission.
  static Future<void> openNotificationSettings() async {
    try {
      await _method.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Launches the system uninstaller dialog for [packageName].
  static Future<void> openAppUninstall(String packageName) async {
    try {
      await _method.invokeMethod('openAppUninstall', {'package': packageName});
    } catch (_) {}
  }
}
