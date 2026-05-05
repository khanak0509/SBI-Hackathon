import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/kavach_service.dart';
import '../widgets/url_feature_breakdown.dart';
import '../widgets/verdict_banner.dart';
import '../widgets/apk_behavior_card.dart';

class ThreatDetailScreen extends StatefulWidget {
  const ThreatDetailScreen({super.key, required this.threatId});

  final String threatId;

  @override
  State<ThreatDetailScreen> createState() => _ThreatDetailScreenState();
}

class _ThreatDetailScreenState extends State<ThreatDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<KavachService>().getThreat(widget.threatId);
  }

  void _retry() => setState(() {
        _future = context.read<KavachService>().getThreat(widget.threatId);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: K.accent)));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center, style: GoogleFonts.nunitoSans(color: K.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _retry, child: const Text('RETRY')),
                  ],
                ),
              ),
            ),
          );
        }
        final t = snap.data!;
        return _ThreatLoadedView(threat: t);
      },
    );
  }
}

class _ThreatLoadedView extends StatefulWidget {
  const _ThreatLoadedView({required this.threat});

  final Map<String, dynamic> threat;

  @override
  State<_ThreatLoadedView> createState() => _ThreatLoadedViewState();
}

class _ThreatLoadedViewState extends State<_ThreatLoadedView> {
  Map<String, dynamic>? _reports;

  Map<String, dynamic> _bannerPayload() {
    final t = widget.threat;
    return {
      'verdict': t['verdict'],
      'confidence': t['confidence'],
      'probability': t['probability'],
    };
  }

  Future<void> _generate() async {
    final svc = context.read<KavachService>();
    final id = widget.threat['id'] as String?;
    if (id == null) return;
    final data = await svc.getReports(id);
    if (!mounted) return;
    setState(() => _reports = data);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: K.surface,
        title: Text('Reports', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(const JsonEncoder.withIndent('  ').convert(data), style: GoogleFonts.dmMono(fontSize: 12, color: K.textPrimary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.threat;
    final verdict = t['verdict'] as String?;
    final isApk = t['threat_type'] == 'apk';
    final flexGrad = (verdict == 'phishing' || verdict == 'fake_apk')
        ? const [Color(0xFF1A0800), Color(0xFF2A1000)]
        : const [Color(0xFF001A0D), Color(0xFF00261A)];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              title: Text(
                '${widget.threat['id']}'.length > 10 ? '${'${widget.threat['id']}'.substring(0, 8)}…' : '${widget.threat['id']}',
                style: GoogleFonts.dmMono(fontSize: 14, color: K.textPrimary),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: flexGrad)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  VerdictBanner(data: _bannerPayload()),
                  const SizedBox(height: 16),
                  _MetaCard(threat: t),
                  const SizedBox(height: 16),
                  if (isApk) _CertCard(threat: t),
                  if (isApk) const SizedBox(height: 16),
                  if (isApk && t['behavior_analysis'] is Map<String, dynamic>)
                    ApkBehaviorCard(behavior: t['behavior_analysis'] as Map<String, dynamic>),
                  if (isApk && t['behavior_analysis'] is Map<String, dynamic>) const SizedBox(height: 16),
                  if (!isApk && t['url_features'] is Map<String, dynamic>) UrlFeatureBreakdown(features: Map<String, dynamic>.from(t['url_features'] as Map)),
                  if (!isApk && t['url_features'] is Map<String, dynamic>) const SizedBox(height: 16),
                  _ReportSection(onGenerate: _generate, reports: _reports),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.threat});

  final Map<String, dynamic> threat;

  @override
  Widget build(BuildContext context) {
    final created = threat['created_at'] as String?;
    DateTime? dt;
    try {
      dt = created != null ? DateTime.tryParse(created) : null;
    } catch (_) {
      dt = null;
    }
    final pretty = dt != null ? DateFormat('dd MMM yyyy · HH:mm:ss').format(dt.toLocal()) : '—';
    final loc = [threat['device_district'], threat['device_state']].whereType<String>().where((e) => e.isNotEmpty).join(', ');
    final ch = threat['source_channel'] as String? ?? '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: K.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
      child: Column(
        children: [
          _metaRow('Detected', pretty),
          const Divider(height: 18),
          _metaRow('Location', loc.isEmpty ? '—' : loc),
          const Divider(height: 18),
          _metaRow('Source channel', ch),
        ],
      ),
    );
  }

  Widget _metaRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: GoogleFonts.dmMono(fontSize: 12, color: K.textSecondary, letterSpacing: 1.0)),
        ),
        Expanded(child: Text(v, style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textPrimary, height: 1.35))),
      ],
    );
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.threat});

  final Map<String, dynamic> threat;

  @override
  Widget build(BuildContext context) {
    final official = threat['cert_is_official'] == true;
    final cert = '${threat['apk_cert_sha256'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: K.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CERTIFICATE', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(official ? Icons.verified : Icons.dangerous, color: official ? K.success : K.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  official ? 'Official SBI signing key' : 'Signing key does not match SBI official certificate',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textSecondary, height: 1.45),
                ),
              ),
            ],
          ),
          if (cert.isNotEmpty) ...[
            const SizedBox(height: 10),
            SelectableText(cert, style: GoogleFonts.dmMono(fontSize: 11, color: K.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.onGenerate, required this.reports});

  final Future<void> Function() onGenerate;
  final Map<String, dynamic>? reports;

  static const _urls = {
    'CERT-In': 'https://www.cert-in.org.in/',
    'Google Safe Browsing': 'https://safebrowsing.google.com/safebrowsing/report_phish/',
    'Cybercrime Portal': 'https://cybercrime.gov.in/',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: K.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUTOMATED REPORTS', style: GoogleFonts.dmMono(fontSize: 10, color: K.textMuted, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(
            'Generate pre-filled reports for submission to CERT-In, Google Safe Browsing, and Cybercrime Portal.',
            style: GoogleFonts.nunitoSans(fontSize: 13, color: K.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.description_outlined),
              label: const Text('GENERATE ALL REPORTS'),
            ),
          ),
          if (reports != null) ...[
            const SizedBox(height: 12),
            _ReportTile(label: 'CERT-In', data: reports!['certin'], url: _urls['CERT-In']!),
            _ReportTile(label: 'Google Safe Browsing', data: reports!['google'], url: _urls['Google Safe Browsing']!),
            _ReportTile(label: 'Cybercrime Portal', data: reports!['cybercrime'], url: _urls['Cybercrime Portal']!),
          ],
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.label, required this.data, required this.url});

  final String label;
  final Object? data;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: K.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.article_outlined, color: K.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w800, color: K.textPrimary)),
                const SizedBox(height: 4),
                Text(url, style: GoogleFonts.dmMono(fontSize: 11, color: K.textMuted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data))),
            icon: const Icon(Icons.copy, size: 18, color: K.textSecondary),
          ),
          IconButton(
            onPressed: () async {
              final u = Uri.parse(url);
              if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new, size: 18, color: K.textSecondary),
          ),
        ],
      ),
    );
  }
}
