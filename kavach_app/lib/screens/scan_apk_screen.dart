import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import '../widgets/apk_behavior_card.dart';
import '../widgets/verdict_banner.dart';

class ScanApkScreen extends StatefulWidget {
  const ScanApkScreen({super.key});

  @override
  State<ScanApkScreen> createState() => _ScanApkScreenState();
}

class _ScanApkScreenState extends State<ScanApkScreen> {
  File? _file;
  String? _name;
  Map<String, dynamic>? _result;
  bool _busy = false;

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['apk']);
    if (r == null || r.files.single.path == null) return;
    setState(() {
      _file = File(r.files.single.path!);
      _name = r.files.single.name;
      _result = null;
    });
  }

  Future<void> _analyze() async {
    final f = _file;
    if (f == null) return;
    setState(() => _busy = true);
    final svc = context.read<KavachService>();
    try {
      final res = await svc.scanApk(f);
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
        _file = null;
        _name = null;
        _result = null;
        _busy = false;
      });

  void _infoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: K.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What is APK scanning?', style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'An APK is the installable package for Android apps. KAVACH inspects the manifest, permissions, '
              'components, and signing certificate. Fake banking apps often reuse similar names but cannot replicate '
              'SBI’s official signing key.',
              style: GoogleFonts.nunitoSans(fontSize: 14, color: K.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ApkResultView(result: _result!, onReset: _reset);
    }
    if (_busy) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analyzing APK...')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: K.accent, strokeWidth: 3),
                const SizedBox(height: 24),
                Text(_name ?? '', style: GoogleFonts.dmMono(fontSize: 13, color: K.textMuted), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Decompiling and checking certificate...\nThis takes 15–30 seconds',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textMuted, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const LinearProgressIndicator(color: K.accent, backgroundColor: K.surface2),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan an APK')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(colors: [K.surface, K.surface2]),
                  border: Border.all(color: K.border),
                ),
                child: const Icon(Icons.android_rounded, size: 64, color: Color(0xFF43A047)),
              ),
              const SizedBox(height: 28),
              Text('Scan an APK File', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'KAVACH inspects the APK and validates its cryptographic signature against SBI\'s official certificate. '
                'Fake apps cannot forge this.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(fontSize: 14, color: K.textMuted, height: 1.6),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('PICK APK FILE'),
                ),
              ),
              if (_file != null) ...[
                const SizedBox(height: 12),
                Text(_name ?? '', style: GoogleFonts.dmMono(fontSize: 12, color: K.textMuted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(Icons.radar_rounded),
                    label: const Text('START SCAN'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: _infoSheet, child: const Text('What is APK scanning?')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApkResultView extends StatelessWidget {
  const _ApkResultView({required this.result, required this.onReset});

  final Map<String, dynamic> result;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final behavior = result['behavior_analysis'];
    final hasBehavior = behavior is Map<String, dynamic>;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('APK Analysis'),
            actions: [
              IconButton(onPressed: onReset, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  VerdictBanner(data: result),
                  const SizedBox(height: 16),
                  _CertificateCard(result: result),
                  const SizedBox(height: 16),
                  if (hasBehavior) ApkBehaviorCard(behavior: behavior),
                  if (hasBehavior) const SizedBox(height: 16),
                  _PackageInfoCard(result: result),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final official = result['cert_is_official'] == true;
    final sha = '${result['sha256'] ?? ''}';

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
              Text('CERTIFICATE CHECK', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
              const Spacer(),
              Icon(official ? Icons.verified : Icons.dangerous, size: 18, color: official ? K.success : K.danger),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: official ? const Color(0xFF001A0D) : const Color(0xFF1A0000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: official ? const Color(0xFF1A4A2A) : const Color(0xFF4A1515)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(official ? Icons.check_circle : Icons.dangerous, color: official ? K.success : K.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        official ? '✓ Official SBI Certificate' : '✗ Certificate Mismatch',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: official ? K.success : K.danger,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        official
                            ? 'This app was signed by State Bank of India'
                            : 'This app was NOT signed by SBI',
                        style: GoogleFonts.nunitoSans(fontSize: 12, color: K.textMuted, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('SHA-256', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: SelectableText(sha.isEmpty ? 'N/A' : sha, style: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary))),
              IconButton(
                onPressed: sha.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: sha)),
                icon: const Icon(Icons.copy_rounded, size: 18, color: K.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageInfoCard extends StatelessWidget {
  const _PackageInfoCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final pkg = '${result['package_name'] ?? ''}';
    final fileSha = '${result['apk_file_sha256'] ?? ''}';
    final svc = context.watch<KavachService>();
    final feats = result['features'];
    double sim = 0;
    if (feats is Map) {
      sim = (feats['package_name_sbi_similarity'] as num?)?.toDouble() ?? 0;
    }
    final imperson = (result['verdict'] == 'fake_apk') || sim > 0.55;

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
          Text('PACKAGE', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 8),
          SelectableText(pkg.isEmpty ? '—' : pkg, style: GoogleFonts.dmMono(fontSize: 13, color: K.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (imperson)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: K.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: K.danger.withValues(alpha: 0.30)),
                  ),
                  child: Text('IMPERSONATING SBI', style: GoogleFonts.dmMono(fontSize: 10, color: K.danger, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('APK FILE SHA-256', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  fileSha.isEmpty ? '—' : fileSha,
                  style: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary),
                ),
              ),
              IconButton(
                onPressed: fileSha.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: fileSha)),
                icon: const Icon(Icons.copy_rounded, size: 18, color: K.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('VERDICT', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(svc.verdictLabel(result['verdict'] as String?), style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w800, color: svc.verdictColor(result['verdict'] as String?))),
        ],
      ),
    );
  }
}
