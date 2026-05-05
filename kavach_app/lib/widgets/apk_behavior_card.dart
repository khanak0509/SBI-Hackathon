import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

String apkPermShort(String p) => p.replaceAll('android.permission.', '').replaceAll('_', ' ').toLowerCase();

class ApkRiskBadge extends StatelessWidget {
  const ApkRiskBadge({super.key, required this.level});

  final String level;

  Color get c => switch (level.toUpperCase()) {
        'HIGH' => K.danger,
        'MEDIUM' => K.warning,
        _ => K.success,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(level, style: GoogleFonts.dmMono(fontSize: 10, color: c, fontWeight: FontWeight.w800)),
    );
  }
}

class ApkRiskMeterBar extends StatelessWidget {
  const ApkRiskMeterBar({super.key, required this.score, required this.level});

  final double score;
  final String level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level.toUpperCase()) {
      'HIGH' => K.danger,
      'MEDIUM' => K.warning,
      _ => K.success,
    };
    final pct = (score.clamp(0.0, 1.0) * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: K.surface2),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct / 100,
                child: Container(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApkBehaviorCard extends StatelessWidget {
  const ApkBehaviorCard({super.key, required this.behavior});

  final Map<String, dynamic> behavior;

  @override
  Widget build(BuildContext context) {
    final level = '${behavior['risk_level'] ?? 'LOW'}';
    final score = (behavior['behavior_risk_score'] as num?)?.toDouble() ?? 0;
    final combos = (behavior['dangerous_combos_detected'] as List?)?.whereType<List>().toList() ?? const <List>[];
    final high = (behavior['high_risk_permissions'] as List?)?.whereType<String>().toList() ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('BEHAVIORAL ANALYSIS', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
              const Spacer(),
              ApkRiskBadge(level: level),
            ],
          ),
          const SizedBox(height: 12),
          ApkRiskMeterBar(score: score, level: level),
          if (combos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('⚠ Dangerous Combinations', style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w800, color: K.danger)),
            const SizedBox(height: 8),
            for (final combo in combos)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: K.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: K.danger.withValues(alpha: 0.25)),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < combo.length; i++) ...[
                        if (i != 0) Text('+', style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w900, color: K.danger)),
                        Chip(
                          label: Text(apkPermShort('${combo[i]}'), style: GoogleFonts.dmMono(fontSize: 10, color: K.danger)),
                          backgroundColor: K.danger.withValues(alpha: 0.10),
                          side: BorderSide(color: K.danger.withValues(alpha: 0.25)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          if (high.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('⚠ High-Risk Permissions', style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w800, color: K.warning)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in high)
                  Chip(
                    label: Text(apkPermShort(p), style: GoogleFonts.dmMono(fontSize: 10, color: K.warning)),
                    backgroundColor: K.warning.withValues(alpha: 0.10),
                    side: BorderSide(color: K.warning.withValues(alpha: 0.25)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
