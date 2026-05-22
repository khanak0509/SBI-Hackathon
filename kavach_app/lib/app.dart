import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'constants.dart';
import 'services/kavach_service.dart';
import 'screens/cybervani_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_apk_screen.dart';
import 'screens/scan_url_screen.dart';
import 'screens/threat_detail_screen.dart';
import 'screens/threat_alert_overlay.dart';
import 'theme/kavach_theme.dart';

class KavachApp extends StatelessWidget {
  const KavachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KAVACH',
      theme: KavachTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: GoRouter(
        routes: [
          ShellRoute(
            builder: (context, state, child) => _Shell(child: child),
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
              GoRoute(path: '/scan-url', builder: (_, __) => const ScanUrlScreen()),
              GoRoute(path: '/scan-apk', builder: (_, __) => const ScanApkScreen()),
              GoRoute(path: '/cybervani', builder: (_, __) => const CyberVaniScreen()),
            ],
          ),
          GoRoute(
            path: '/threat/:id',
            builder: (_, s) => ThreatDetailScreen(threatId: s.pathParameters['id']!),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.child});
  final Widget child;
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {

      context.read<KavachService>().checkPendingThreat();
    }
  }

  int _indexForPath(String path) {
    if (path.startsWith('/scan-url')) return 1;
    if (path.startsWith('/scan-apk')) return 2;
    if (path.startsWith('/cybervani')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final idx = _indexForPath(path);

    final svc = context.watch<KavachService>();
    final activeThreat = svc.activeThreat;

    return Stack(
      children: [
        Scaffold(
          body: widget.child,
          bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: K.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) {
            switch (i) {
              case 0:
                context.go('/');
              case 1:
                context.go('/scan-url');
              case 2:
                context.go('/scan-apk');
              case 3:
                context.go('/cybervani');
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.link_outlined),
              activeIcon: Icon(Icons.link),
              label: 'Scan URL',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.android_outlined),
              activeIcon: Icon(Icons.android),
              label: 'Scan APK',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Learn',
            ),
          ],
        ),
      ),
    ),
      if (activeThreat != null)
        ThreatAlertOverlay(
          appName: activeThreat['package_name']?.split('.').last ?? 'Unknown App',
          packageName: activeThreat['package_name'] ?? 'com.unknown.app',
          similarity: (activeThreat['similarity'] as num?)?.toDouble() ?? 0.8,
          onDismiss: svc.clearActiveThreat,
        ),
    ],
  );
}
}

