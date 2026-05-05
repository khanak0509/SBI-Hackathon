import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import '../widgets/url_feature_breakdown.dart';
import '../widgets/verdict_banner.dart';

class ScanUrlScreen extends StatefulWidget {
  const ScanUrlScreen({super.key});

  @override
  State<ScanUrlScreen> createState() => _ScanUrlScreenState();
}

class _ScanUrlScreenState extends State<ScanUrlScreen> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    final svc = context.read<KavachService>();
    try {
      final r = await svc.scanUrl(url);
      setState(() => _result = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ResultView(
        result: _result!,
        onBack: () => setState(() => _result = null),
      );
    }

    final loading = context.watch<KavachService>().isLoading;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('Scan a Link'),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Is this link safe?', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Paste any suspicious URL. KAVACH checks 16 risk signals instantly.',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: K.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: K.border),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _ctrl,
                            minLines: 3,
                            maxLines: 5,
                            style: GoogleFonts.dmMono(fontSize: 13, color: K.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Paste URL here e.g. http://sbi-kyc.xyz/login...',
                              hintStyle: GoogleFonts.dmMono(fontSize: 13, color: K.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _ChipUrl(
                                      label: 'sbi-kyc.xyz',
                                      onTap: () => _ctrl.text = 'http://sbi-kyc.xyz/login',
                                    ),
                                    _ChipUrl(
                                      label: 'yono-update.top',
                                      onTap: () => _ctrl.text = 'https://yono-update.top/',
                                    ),
                                    _ChipUrl(
                                      label: '192.168.1.1/sbi',
                                      onTap: () => _ctrl.text = 'http://192.168.1.1/sbi',
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => setState(_ctrl.clear),
                                icon: const Icon(Icons.clear_rounded, color: K.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _scan,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.radar_rounded),
                      label: Text(loading ? 'ANALYZING...' : 'SCAN NOW'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Results appear below after scanning',
                      style: GoogleFonts.nunitoSans(fontSize: 11, color: K.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipUrl extends StatelessWidget {
  const _ChipUrl({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: K.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: K.border),
        ),
        child: Text(label, style: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary)),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, required this.onBack});

  final Map<String, dynamic> result;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final feats = Map<String, dynamic>.from(result['features'] as Map? ?? {});
    final verdict = result['verdict'] as String?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Scan Result'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  VerdictBanner(data: result),
                  const SizedBox(height: 16),
                  _ScoreCard(features: feats, verdict: verdict),
                  const SizedBox(height: 16),
                  if (verdict == 'phishing') const _PhishingWarningCard(),
                  if (verdict == 'phishing') const SizedBox(height: 16),
                  UrlFeatureBreakdown(features: feats),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: onBack, child: const Text('SCAN ANOTHER LINK')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhishingWarningCard extends StatelessWidget {
  const _PhishingWarningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: K.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: K.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This URL exhibits strong phishing characteristics. Do not enter credentials, OTP, or install any suggested APK.',
              style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textPrimary, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.features, required this.verdict});

  final Map<String, dynamic> features;
  final String? verdict;

  @override
  Widget build(BuildContext context) {
    final keys = ['has_sbi_keyword', 'suspicious_tld', 'has_ip_address', 'uses_https', 'levenshtein_to_sbi'];
    final vals = keys.map((k) => (features[k] is num) ? (features[k] as num).toDouble() : double.tryParse('${features[k]}') ?? 0).toList();

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
          Text(
            'SIGNAL MIX',
            style: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary, letterSpacing: 2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt().clamp(0, keys.length - 1);
                        final short = keys[i].replaceAll('has_', '').replaceAll('_', '\n');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(short, textAlign: TextAlign.center, style: GoogleFonts.dmMono(fontSize: 9, color: K.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < keys.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: keys[i] == 'levenshtein_to_sbi' ? vals[i].clamp(0, 40) : vals[i].clamp(0, 1) * 10,
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              (verdict == 'phishing' ? K.warning : K.primary).withValues(alpha: 0.35),
                              verdict == 'phishing' ? K.warning : K.accent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
