import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

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

class _InterceptorTestState extends State<InterceptorTest> {
  List<ServiceNotificationEvent> interceptedEvents = [];
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
    _subscription = NotificationListenerService.notificationsStream.listen((event) {
      // Ignore empty system noise
      if (event.content == null || event.content!.isEmpty) return;

      // Print to Mac terminal
      debugPrint("----- NEW MESSAGE CAUGHT -----");
      debugPrint("App Package: ${event.packageName}");
      debugPrint("Sender: ${event.title}");
      debugPrint("Message: ${event.content}");
      
      // Update the phone screen UI
      setState(() {
        interceptedEvents.insert(0, event); // Add new messages to the top
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test 1: Raw Interceptor'), backgroundColor: Colors.amber),
      body: interceptedEvents.isEmpty
          ? const Center(child: Text("Waiting for a notification..."))
          : ListView.builder(
              itemCount: interceptedEvents.length,
              itemBuilder: (context, index) {
                final event = interceptedEvents[index];
                return ListTile(
                  leading: const Icon(Icons.message, color: Colors.blue),
                  title: Text(event.title ?? "Unknown Sender", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(event.content ?? "No text"),
                  trailing: Text(
                    event.packageName?.split('.').last ?? "", 
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}