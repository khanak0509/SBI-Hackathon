import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import 'confidence_bar.dart';

class VerdictCard extends StatelessWidget {
  const VerdictCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<KavachService>();
    final verdict = data['verdict'] as String?;
    final conf = (data['confidence'] as num?)?.toDouble() ?? 0;
    final color = service.verdictColor(verdict);
    final label = service.verdictLabel(verdict);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              verdict == 'safe' ? Icons.verified_outlined : Icons.shield_moon_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                ConfidenceBar(conf, height: 4),
                const SizedBox(height: 3),
                Text(
                  '${(conf * 100).toStringAsFixed(1)}% confidence',
                  style: GoogleFonts.dmMono(fontSize: 11, color: K.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
