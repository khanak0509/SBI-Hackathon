import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

const String backendBaseUrl = "http://172.31.108.237:8000";
void main() {
  runApp(const MyApp());
}

class MyApp extends MaterialApp {
  const MyApp({super.key}) : super(home: const InterceptorTest(), debugShowCheckedModeBanner: false);
}

class InterceptorTest extends StatefulWidget {
  const InterceptorTest({super.key});

  @override
  State<InterceptorTest> createState() => _InterceptorTestState();
}

class InterceptedMessage {
  final ServiceNotificationEvent event;
  final String? backendReply;

  InterceptedMessage({
    required this.event,
    this.backendReply,
  });
}

class _InterceptorTestState extends State<InterceptorTest> {
  final List<InterceptedMessage> _messages = [];
  StreamSubscription<ServiceNotificationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  
  
  void _startListening() async {
    // 1. Check and request Notification Access
    bool isGranted = await NotificationListenerService.isPermissionGranted();
    if (!isGranted) {
      debugPrint("Requesting Notification Access...");
      await NotificationListenerService.requestPermission();
    }

    // 2. Listen to the stream of notifications
    _subscription = NotificationListenerService.notificationsStream.listen((event) async {
      // Ignore empty system noise
      if (event.content == null || event.content!.isEmpty) return;

      // Print to Mac terminal
      debugPrint("----- NEW MESSAGE CAUGHT -----");
      debugPrint("App Package: ${event.packageName}");
      debugPrint("Sender: ${event.title}");
      debugPrint("Message: ${event.content}");

      // Send to backend and wait for response
      final backendReply = await sendNotification(
        event.title ?? "Unknown Sender",
        event.content ?? "",
        event.packageName ?? "",
      );

      // Update the phone screen UI with both notification and backend reply
      setState(() {
        _messages.insert(
          0,
          InterceptedMessage(
            event: event,
            backendReply: backendReply,
          ),
        ); // Add new messages to the top
      });
    });
  }



Future<String?> sendNotification(
  String sender,
  String content,
  String packageName,
) async {
  final url = Uri.parse("$backendBaseUrl/send_notification");

  try {
    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "sender": sender,
        "content": content,
        "package_name": packageName,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint("Response status: ${data['status']}");
      return data['response'] as String?;
    } else {
      debugPrint("Error: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    debugPrint("Exception: $e");
    return null;
  }
}

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Smart Notification Assistant',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    "Waiting for a notification...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final event = message.event;
                    final reply = message.backendReply;

                    return Card(
                      color: const Color(0xFF1F2937),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.blueAccent,
                                  child: Icon(
                                    Icons.message,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title ?? "Unknown Sender",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.content ?? "No text",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  event.packageName?.split('.').last ?? "",
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (reply != null && reply.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.smart_toy_outlined,
                                      color: Colors.greenAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        reply,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}