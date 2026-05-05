import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';

import '../services/native_bridge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _notificationAccessGranted = true; // Assume true until checked

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationAccess();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationAccess();
    }
  }

  Future<void> _checkNotificationAccess() async {
    final granted = await NativeBridge.hasNotificationAccess();
    if (mounted) {
      setState(() {
        _notificationAccessGranted = granted;
      });
      if (!granted) {
        _showPermissionBottomSheet();
      } else {
        if (Navigator.of(context).canPop()) {
           // We might have the bottom sheet open, but let's be careful not to pop something else.
           // Actually, it's safer to let the user press "Skip" or we could pop specifically.
        }
      }
    }
  }

  void _showPermissionBottomSheet() {
    // Only show if not already showing
    if (ModalRoute.of(context)?.isCurrent != true) return;
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: K.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 48, color: K.accent),
              const SizedBox(height: 16),
              Text(
                'Notification Scanning Required',
                textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: K.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'KAVACH needs to read notification banners to warn you about fake SBI links the moment they arrive. We never read your SMS inbox.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  fontSize: 14,
                  color: K.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: K.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  NativeBridge.openNotificationSettings();
                  Navigator.pop(context);
                },
                child: Text(
                  'GRANT ACCESS',
                  style: GoogleFonts.rajdhani(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 14,
                    color: K.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: K.bg,
            flexibleSpace: FlexibleSpaceBar(background: const _HeroHeader()),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  const _StatusCard(),
                  if (!_notificationAccessGranted)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1500),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF5A2D00)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification scanning inactive',
                                    style: GoogleFonts.rajdhani(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    'Grant access to detect fake links automatically',
                                    style: GoogleFonts.nunitoSans(
                                      fontSize: 11,
                                      color: K.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => NativeBridge.openNotificationSettings(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('ENABLE'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const _StatsRow(),
                  const SizedBox(height: 24),
                  const _QuickActions(),
                  const SizedBox(height: 24),
                  const _RecentAlertsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final active = context.watch<KavachService>().isWatchActive;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D0F1A), Color(0xFF1A237E), Color(0xFF0D0F1A)],
              transform: GradientRotation(135 * math.pi / 180),
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 20, color: K.accent),
                        const SizedBox(width: 8),
                        Text(
                          'STATE BANK OF INDIA',
                          style: GoogleFonts.dmMono(
                            fontSize: 10,
                            color: K.textMuted,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KAVACH',
                      style: GoogleFonts.rajdhani(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: K.textPrimary,
                      ),
                    ),
                    Text(
                      'Fraud Protection System',
                      style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textSecondary),
                    ),
                  ],
                ),
              ),
              _ShieldBadge(active: active),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(begin: K.primary, end: active ? K.success : K.primary),
      duration: const Duration(milliseconds: 650),
      builder: (context, color, child) {
        final c = color ?? K.primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? K.success : K.primary, width: 2),
            color: K.surface.withValues(alpha: 0.35),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: Icon(Icons.shield, size: 34, color: active ? K.success : K.primary),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<KavachService>(
      builder: (context, svc, _) {
        final active = svc.isWatchActive;
        final stats = svc.stats;
        final grad = active
            ? const [Color(0xFF0A1628), Color(0xFF0D2137)]
            : const [Color(0xFF1A0A0A), Color(0xFF200D0D)];
        final border = active ? const Color(0xFF1A3A5C) : const Color(0xFF4A1515);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.read<KavachService>().toggleWatch(),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: grad),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          active ? Icons.verified_user : Icons.shield_outlined,
                          size: 28,
                          color: active ? K.success : K.danger,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROTECTION ${active ? 'ACTIVE' : 'INACTIVE'}',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: active ? K.success : K.danger,
                                ),
                              ),
                              Text(
                                active ? 'Live correlation with KAVACH intelligence cloud' : 'Tap to activate KAVACH',
                                style: GoogleFonts.nunitoSans(fontSize: 12, color: K.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (active) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _MiniStat(
                            label: 'Threats Today',
                            value: '${stats?['total_threats_24h'] ?? '—'}',
                          ),
                          _MiniStat(
                            label: 'APK Scans',
                            value: '${stats?['by_type']?['apk'] ?? '—'}',
                          ),
                          _MiniStat(
                            label: 'URL Scans',
                            value: '${stats?['by_type']?['url'] ?? '—'}',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w700, color: K.accent),
          ),
          Text(label, style: GoogleFonts.nunitoSans(fontSize: 10, color: K.textMuted)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<KavachService>().stats;
    final t24 = stats?['total_threats_24h']?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _StatTile(icon: Icons.warning_amber_rounded, iconColor: K.warning, value: t24, caption: 'Threats (24h)')),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle_outline,
              iconColor: K.success,
              value: 'Active',
              caption: 'Shield Active',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.rajdhani(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: iconColor == K.warning ? K.warning : K.success,
                  ),
                ),
                Text(caption, style: GoogleFonts.nunitoSans(fontSize: 12, color: K.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionTile(
                icon: Icons.link_rounded,
                label: 'Scan URL',
                color: K.primary,
                onTap: () => context.go('/scan-url'),
              ),
              _ActionTile(
                icon: Icons.android_rounded,
                label: 'Scan APK',
                color: const Color(0xFF43A047),
                onTap: () => context.go('/scan-apk'),
              ),
              _ActionTile(
                icon: Icons.school_outlined,
                label: 'CyberVani',
                color: K.accent,
                onTap: () => context.go('/cybervani'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: K.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: K.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
                  ],
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: K.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAlertsSection extends StatelessWidget {
  const _RecentAlertsSection();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<KavachService>();
    final items = svc.recentThreats.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RECENT ALERTS',
                style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => svc.loadRecentThreats(),
                child: Text(
                  'Refresh →',
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: K.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const _EmptyState()
          else
            Column(children: [for (final t in items) _ThreatListTile(threat: t)]),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: K.textMuted, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No threats detected. You\'re protected.',
              style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime? dt) {
  if (dt == null) return '—';
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('dd MMM').format(dt);
}

class _ThreatListTile extends StatelessWidget {
  const _ThreatListTile({required this.threat});

  final Map<String, dynamic> threat;

  String _subtitle() {
    if (threat['threat_type'] == 'apk') {
      return '${threat['apk_package_name'] ?? threat['raw_input'] ?? ''}';
    }
    return '${threat['malicious_domain'] ?? threat['raw_input'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<KavachService>();
    final id = threat['id'] as String? ?? '';
    final verdict = threat['verdict'] as String?;
    final created = threat['created_at'] as String?;
    final label = svc.verdictLabel(verdict);
    final color = svc.verdictColor(verdict);
    final icon = threat['threat_type'] == 'apk' ? Icons.android : Icons.link;

    DateTime? dt;
    try {
      dt = created != null ? DateTime.tryParse(created) : null;
    } catch (_) {
      dt = null;
    }
    final ago = _ago(dt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/threat/$id'),
          child: Ink(
            decoration: BoxDecoration(
              color: K.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: K.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                          ),
                          const Spacer(),
                          Text(ago, style: GoogleFonts.dmMono(fontSize: 11, color: K.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmMono(fontSize: 12, color: K.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: K.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
