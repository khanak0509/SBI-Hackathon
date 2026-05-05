import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';

class BackendClient {
  BackendClient({this.baseUrl = K.backendUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> scanUrl(
    String url, {
    String channel = 'manual',
    Map<String, dynamic>? device,
  }) async {
    final body = <String, dynamic>{'url': url, 'source_channel': channel};
    if (device != null) body.addAll(device);
    final res = await http
        .post(
          Uri.parse('$baseUrl/scan/url'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('URL scan failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> scanApk(File file, {Map<String, dynamic>? device}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan/apk'));
    req.fields['source_channel'] = 'manual';
    if (device != null) {
      device.forEach((k, v) {
        if (v != null) req.fields[k] = v.toString();
      });
    }
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send().timeout(const Duration(minutes: 5));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('APK scan failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> reportBackgroundThreat({
    required String packageName,
    required double similarity,
    Map<String, dynamic>? device,
  }) async {
    final body = <String, dynamic>{
      'package_name': packageName,
      'similarity': similarity,
      'source_channel': 'background',
    };
    if (device != null) body.addAll(device);
    final res = await http.post(
      Uri.parse('$baseUrl/report/background_threat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to report background threat: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getThreats({int limit = 50}) async {
    final res = await http.get(Uri.parse('$baseUrl/threats?limit=$limit')).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load threats');
  }

  Future<Map<String, dynamic>> getThreat(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/threats/$id')).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load threat');
  }

  Future<Map<String, dynamic>> getStats() async {
    final res = await http.get(Uri.parse('$baseUrl/threats/stats')).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load stats');
  }

  Future<Map<String, dynamic>> getAllReports(String threatId) async {
    final res = await http.post(Uri.parse('$baseUrl/reports/$threatId/all')).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to generate reports');
  }
}
