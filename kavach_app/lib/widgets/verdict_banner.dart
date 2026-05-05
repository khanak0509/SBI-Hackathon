import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import 'confidence_bar.dart';

class VerdictBanner extends StatelessWidget {
  const VerdictBanner({
    super.key,
    required this.data,
    this.compact = false,
  });

  final Map<String, dynamic> data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<KavachService>();
    final verdict = data['verdict'] as String?;
    final conf = (data['confidence'] as num?)?.toDouble() ?? 0;
    final prob = (data['probability'] as num?)?.toDouble() ?? 0;
    final label = service.verdictLabel(verdict);
    final color = service.verdictColor(verdict);
    final isPhish = verdict == 'phishing' || verdict == 'fake_apk';
    final grad = isPhish
        ? const [Color(0xFF1A0800), Color(0xFF2A1000)]
        : const [Color(0xFF001A0D), Color(0xFF00261A)];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: grad),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              verdict == 'safe' ? Icons.verified_rounded : Icons.warning_rounded,
              color: color,
              size: compact ? 26 : 32,
            ),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: compact ? 18 : 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                ConfidenceBar(conf, height: compact ? 4 : 8),
                const SizedBox(height: 4),
                Text(
                  '${(prob * 100).toStringAsFixed(1)}% model score',
                  style: GoogleFonts.dmMono(fontSize: compact ? 10 : 12, color: K.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
