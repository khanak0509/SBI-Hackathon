import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);

    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showThreatAlert(String title, String body) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'kavach_critical',
        'KAVACH Critical Alerts',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        color: const Color(0xFFE53935),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
