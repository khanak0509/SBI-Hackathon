import 'package:flutter/material.dart';

/// Local security-lab APK only — not a real bank app. Package id is SBI-shaped
/// on purpose so KAVACH / Drebin-style scanners can be exercised offline.
void main() {
  runApp(const LabApp());
}

class LabApp extends StatelessWidget {
  const LabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBI ML Lab (fake)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LabHomePage(),
    );
  }
}

class LabHomePage extends StatelessWidget {
  const LabHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YONO-style lab build'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security lab APK',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'This project exists only to build a debug APK with an '
              'SBI-like applicationId and high-risk permissions declared '
              'in AndroidManifest.xml so you can run train2.py / test3.py '
              'against a real binary.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Do not publish, sideload to victims, or submit to stores.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
