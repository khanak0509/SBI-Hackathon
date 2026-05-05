import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'constants.dart';
import 'services/kavach_service.dart';
import 'services/native_bridge.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await NotificationService.init();

  // ── Self-integrity check ──────────────────────────────────────────────────
  // Only runs in release builds. In debug mode (flutter run / dev) the app
  // is signed with a debug key — so we skip this check intentionally.
  // In a production release the officialCertHash must match SBI's release key.
  if (!kDebugMode) {
    final trusted = await NativeBridge.verifyIntegrity(K.officialCertHash);
    if (!trusted) {
      runApp(_TamperedApp());
      return;
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  runApp(
    ChangeNotifierProvider(
      create: (_) => KavachService()..initialize(),
      child: const KavachApp(),
    ),
  );
}

/// Shown when the app's signing cert does not match the pinned SBI hash.
/// The user cannot proceed — they must uninstall and re-download from Play Store.
class _TamperedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A0000),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.report_problem_rounded,
                    color: Color(0xFFE53935), size: 80),
                const SizedBox(height: 24),
                const Text(
                  'APP INTEGRITY FAILURE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE53935),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app has been tampered with and does not carry '
                  'the official SBI signing certificate.\n\n'
                  'Uninstall it immediately and re-download KAVACH '
                  'from the official Google Play Store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE8EAF6),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
