import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import '../widgets/verdict_banner.dart';

class _Module {
  const _Module({
    required this.emoji,
    required this.accent,
    required this.hindi,
    required this.english,
    required this.content,
    required this.tip,
  });

  final String emoji;
  final Color accent;
  final String hindi;
  final String english;
  final String content;
  final String tip;
}

class CyberVaniScreen extends StatefulWidget {
  const CyberVaniScreen({super.key});

  @override
  State<CyberVaniScreen> createState() => _CyberVaniScreenState();
}

class _CyberVaniScreenState extends State<CyberVaniScreen> {
  final _urlCtrl = TextEditingController();
  Map<String, dynamic>? _quick;
  final Set<int> _open = {};

  static const _modules = <_Module>[
    _Module(
      emoji: '📱',
      accent: Color(0xFFE53935),
      hindi: 'KYC कभी SMS से नहीं होती',
      english: 'SBI never asks for KYC via SMS',
      content:
          'SBI बैंक कभी भी SMS या WhatsApp के through KYC update नहीं करती। अगर कोई message आए कि \'आपका KYC expire हो रहा है, इस link पर click करें\' — यह 100% fraud है। असली SBI केवल official branch में या YONO app में KYC करती है।',
      tip: 'Rule: कोई भी SMS जो link के साथ KYC माँगे — वो fraud है। हमेशा।',
    ),
    _Module(
      emoji: '🔒',
      accent: Color(0xFFF57C00),
      hindi: 'Official Store से ही Download करें',
      english: 'Never install APKs from unknown links',
      content:
          'YONO app केवल Google Play Store से download करें। WhatsApp या Telegram पर भेजी गई APK files कभी install न करें। Fake apps बिल्कुल असली जैसी दिखती हैं लेकिन उनका digital signature अलग होता है — KAVACH यही check करता है।',
      tip: 'YONO को Google Play पर search करें — developer \'State Bank of India\', 5 crore+ downloads।',
    ),
    _Module(
      emoji: '🔗',
      accent: Color(0xFF1565C0),
      hindi: 'Link click करने से पहले सोचें',
      english: 'How to spot a phishing link',
      content:
          'Phishing links में ये signs होते हैं: domain में extra words (sbi-kyc-update.xyz), HTTPS की जगह HTTP, raw IP address (192.168.1.1/sbi), या urgency words जैसे \'अभी click करें वरना account बंद\'। KAVACH 16 signals check करता है automatically।',
      tip: 'Real SBI links: onlinesbi.sbi या sbi.co.in — बस। कोई और domain fake है।',
    ),
    _Module(
      emoji: '🔑',
      accent: Color(0xFF43A047),
      hindi: 'OTP और MPIN कभी Share न करें',
      english: 'Your OTP is yours alone — always',
      content:
          'SBI का कोई भी employee कभी OTP, MPIN, या debit card details नहीं माँगता — phone पर, SMS पर, या किसी app में। OTP 30 seconds में expire हो जाता है। अगर कोई माँगे — वो fraud है, bank employee नहीं।',
      tip: 'SBI कभी call करके OTP नहीं माँगती। कोई माँगे → तुरंत काटें।',
    ),
    _Module(
      emoji: '✅',
      accent: Color(0xFF7C4DFF),
      hindi: 'असली YONO की पहचान',
      english: 'How to verify the genuine YONO app',
      content:
          'Google Play पर असली YONO: Developer \'State Bank of India\', 5 crore+ downloads, 4.2+ rating, published 2011। Fake apps: अलग developer, कम downloads, recently published। KAVACH APK का cryptographic signature check करता है — यह spoof नहीं हो सकता।',
      tip: 'KAVACH का \'Scan APK\' feature use करें किसी भी YONO जैसी app को verify करने के लिए।',
    ),
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickScan() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final svc = context.read<KavachService>();
    try {
      final r = await svc.scanUrl(url, channel: 'manual');
      setState(() => _quick = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _open.length / 5.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_stories_outlined, color: K.accent),
            const SizedBox(width: 8),
            const Text('CyberVani'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(value: progress, minHeight: 3, color: K.accent, backgroundColor: K.surface2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF0D1240), Color(0xFF1A0D40)]),
                border: Border.all(color: const Color(0xFF2A2060)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFF57C00)],
                          ).createShader(rect),
                          child: Text(
                            'साइबर सुरक्षा',
                            style: GoogleFonts.rajdhani(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Learn to protect yourself from banking fraud',
                          style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textMuted, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatPill(text: '5 Modules'),
                            const SizedBox(width: 8),
                            _StatPill(text: 'Hindi + English'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.security, size: 56, color: Color(0xFF7C4DFF)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (var mi = 0; mi < _modules.length; mi++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: K.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: K.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      onExpansionChanged: (open) => setState(() {
                        if (open) {
                          _open.add(mi);
                        } else {
                          _open.remove(mi);
                        }
                      }),
                      tilePadding: const EdgeInsets.all(16),
                      childrenPadding: EdgeInsets.zero,
                      iconColor: K.accent,
                      collapsedIconColor: K.textMuted,
                      backgroundColor: K.surface,
                      collapsedBackgroundColor: K.surface,
                      title: Builder(
                        builder: (context) {
                          final m = _modules[mi];
                          return Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: m.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(m.emoji, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.hindi, style: GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.w800, color: K.textPrimary)),
                                    Text(m.english, style: GoogleFonts.nunitoSans(fontSize: 12, color: K.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      children: [
                        Builder(
                          builder: (context) {
                            final m = _modules[mi];
                            return Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: K.surface2,
                                border: Border(top: BorderSide(color: K.border)),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.content,
                                    style: GoogleFonts.nunitoSans(fontSize: 14, color: K.textSecondary, height: 1.75),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: K.primary.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: K.primary.withValues(alpha: 0.30)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.lightbulb_outline, color: K.primary, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(m.tip, style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textSecondary, height: 1.45)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text('QUICK URL CHECK', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(hintText: 'Paste a suspicious URL...'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _quickScan, child: const Text('CHECK')),
              ],
            ),
            if (_quick != null) ...[
              const SizedBox(height: 12),
              VerdictBanner(data: _quick!, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: K.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: K.border),
      ),
      child: Text(text, style: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary)),
    );
  }
}
