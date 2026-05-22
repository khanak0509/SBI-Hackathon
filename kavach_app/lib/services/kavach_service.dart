import 'dart:io';

import 'package:flutter/material.dart';

import 'backend_client.dart';
import 'location_service.dart';
import 'native_bridge.dart';
import 'notification_service.dart';

class KavachService extends ChangeNotifier {
  KavachService() : _client = BackendClient();

  final BackendClient _client;

  bool isLoading = false;
  bool isWatchActive = false;
  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> recentThreats = [];
  String? errorMessage;
  Map<String, dynamic>? lastUrlResult;
  Map<String, dynamic>? lastApkResult;
  Map<String, dynamic>? deviceLocationFields;
  Map<String, dynamic>? activeThreat;
  String? _lastReportedPackage;
  DateTime? _lastReportedTime;
  final Set<String> _reportingPackages = {};

  void clearActiveThreat() {
    activeThreat = null;
    notifyListeners();
  }

  void toggleWatch() {
    isWatchActive = !isWatchActive;
    notifyListeners();
  }

  Future<void> initialize() async {
    isWatchActive = true;
    notifyListeners();

    await refreshDeviceLocation();

    NativeBridge.packageThreatStream.listen((event) async {
      debugPrint("KAVACH_DEBUG: Received package threat stream event! $event");
      final pkg = event['package_name'] ?? 'unknown';
      final sim = event['similarity'] ?? 0.8;

      activeThreat = {
        'package_name': pkg,
        'verdict': 'fake_apk',
        'confidence': sim,
      };
      notifyListeners();

      await reportThreatToDashboard(pkg, (sim as num).toDouble());
    }, onError: (e) {
      debugPrint("KAVACH_DEBUG: Event channel error: $e");
    });

    await loadStats();
    await loadRecentThreats();

    await checkPendingThreat();
  }

  Future<void> reportThreatToDashboard(String pkg, double similarity) async {

    final now = DateTime.now();
    if (_lastReportedPackage == pkg &&
        _lastReportedTime != null &&
        now.difference(_lastReportedTime!).inSeconds < 30) {
      debugPrint("KAVACH_DEBUG: Skipping duplicate report (time-based) for $pkg");
      return;
    }

    if (_reportingPackages.contains(pkg)) {
      debugPrint("KAVACH_DEBUG: Skipping duplicate report (lock-based) for $pkg");
      return;
    }
    _reportingPackages.add(pkg);

    _lastReportedPackage = pkg;
    _lastReportedTime = now;

    int retries = 0;
    while (deviceLocationFields == null && retries < 8) {
      debugPrint("KAVACH_DEBUG: Location missing, fetching... (Attempt ${retries + 1})");
      await refreshDeviceLocation();
      if (deviceLocationFields != null) break;
      await Future.delayed(const Duration(milliseconds: 1000));
      retries++;
    }

    try {
      debugPrint("KAVACH_DEBUG: Reporting $pkg to dashboard with location: $deviceLocationFields");
      await _client.reportBackgroundThreat(
        packageName: pkg,
        similarity: similarity,
        device: deviceLocationFields,
      );
      await loadRecentThreats();
    } catch (e) {
      debugPrint("KAVACH_DEBUG: Failed to report background threat to dashboard: $e");
    } finally {
      _reportingPackages.remove(pkg);
    }
  }

  Future<void> checkPendingThreat() async {
    debugPrint("KAVACH_DEBUG: checkPendingThreat called!");
    final threat = await NativeBridge.checkPendingPackageThreat();
    debugPrint("KAVACH_DEBUG: checkPendingPackageThreat returned: $threat");
    if (threat != null) {
      final pkg = threat['package_name'] ?? 'unknown';
      final sim = (threat['similarity'] as num?)?.toDouble() ?? 0.8;

      activeThreat = threat;
      await NativeBridge.clearPendingPackageThreat();
      notifyListeners();

      await reportThreatToDashboard(pkg, sim);
    }
  }

  Future<void> refreshDeviceLocation() async {
    try {
      final snap = await captureDeviceLocation();
      if (snap != null) {
        deviceLocationFields = snap.toScanFields();
        debugPrint("KAVACH_DEBUG: Location updated: ${deviceLocationFields!['device_city']}");
      }
    } catch (e) {
      debugPrint("KAVACH_DEBUG: Failed to refresh location: $e");
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _deviceMetaForScan() async {
    try {
      final snap = await captureDeviceLocation().timeout(const Duration(seconds: 14));
      if (snap != null) deviceLocationFields = snap.toScanFields();
    } catch (_) {}
    notifyListeners();
    return deviceLocationFields;
  }

  Future<void> loadStats() async {
    try {
      stats = await _client.getStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadRecentThreats() async {
    try {
      final data = await _client.getThreats(limit: 20);
      recentThreats = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> scanUrl(String url, {String channel = 'manual'}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final meta = await _deviceMetaForScan();
      final result = await _client.scanUrl(url, channel: channel, device: meta);
      lastUrlResult = result;
      if (result['verdict'] == 'phishing') {
        await NotificationService.showThreatAlert(
          '🚨 Phishing Link Detected',
          'A dangerous link was just scanned. Do not visit this URL.',
        );
        await loadRecentThreats();
      }
      return result;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> scanApk(File file) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final meta = await _deviceMetaForScan();
      final result = await _client.scanApk(file, device: meta);
      lastApkResult = result;
      if (result['verdict'] == 'fake_apk') {
        activeThreat = result;
        await NotificationService.showThreatAlert(
          '🚨 Fake YONO App Detected',
          '${result['package_name'] ?? 'An app'} is a fake SBI app. Uninstall immediately.',
        );
        await loadRecentThreats();
      }
      return result;
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getReports(String threatId) => _client.getAllReports(threatId);

  Future<Map<String, dynamic>> getThreat(String id) => _client.getThreat(id);

  Color verdictColor(String? verdict) => switch (verdict) {
        'phishing' => const Color(0xFFFFA000),
        'fake_apk' => const Color(0xFFE53935),
        'review' => const Color(0xFF1565C0),
        'safe' => const Color(0xFF00C853),
        _ => const Color(0xFF4A5073),
      };

  String verdictLabel(String? verdict) => switch (verdict) {
        'phishing' => 'PHISHING URL',
        'fake_apk' => 'FAKE APP',
        'review' => 'NEEDS REVIEW',
        'safe' => 'SAFE',
        _ => 'UNKNOWN',
      };
}
