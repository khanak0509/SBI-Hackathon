import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

const _kOrder = <String>[
  'url_length',
  'domain_length',
  'num_dots',
  'num_hyphens',
  'num_underscores',
  'num_slashes',
  'num_query_params',
  'has_ip_address',
  'has_at_symbol',
  'has_double_slash',
  'uses_https',
  'has_port',
  'num_subdomains',
  'levenshtein_to_sbi',
  'suspicious_tld',
  'has_sbi_keyword',
];

String _title(String k) => k.replaceAll('_', ' ');

class UrlFeatureBreakdown extends StatelessWidget {
  const UrlFeatureBreakdown({super.key, required this.features});

  final Map<String, dynamic> features;

  bool _isBinary(dynamic v) => v is int || (v is double && v == v.roundToDouble());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'FEATURE ANALYSIS',
              style: GoogleFonts.dmMono(
                fontSize: 10,
                color: K.textMuted,
                letterSpacing: 2,
              ),
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < _kOrder.length; i++) ...[
            _row(_kOrder[i], features[_kOrder[i]]),
            if (i != _kOrder.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _row(String key, dynamic raw) {
    final risky = {'suspicious_tld', 'has_ip_address', 'has_at_symbol', 'has_sbi_keyword', 'has_port'};
    final good = key == 'uses_https';
    final v = raw ?? 0;
    final binary = _isBinary(v);

    Widget right;
    if (binary) {
      final iv = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
      final isRisk = risky.contains(key) && iv == 1;
      final isGood = good && iv == 1;
      Color bg;
      Color fg;
      String text;
      if (isRisk) {
        bg = K.danger.withValues(alpha: 0.12);
        fg = K.danger;
        text = 'YES';
      } else if (isGood) {
        bg = K.success.withValues(alpha: 0.12);
        fg = K.success;
        text = 'YES';
      } else if (iv == 1) {
        bg = K.surface2;
        fg = K.textSecondary;
        text = 'YES';
      } else {
        bg = K.surface2;
        fg = K.textMuted;
        text = 'NO';
      }
      right = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Text(text, style: GoogleFonts.dmMono(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
      );
    } else {
      right = Text('$v', style: GoogleFonts.dmMono(fontSize: 13, color: K.accent));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title(key),
              style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textSecondary),
            ),
          ),
          right,
        ],
      ),
    );
  }
}
