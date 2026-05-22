import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/native_bridge.dart';

class ThreatAlertOverlay extends StatelessWidget {
  const ThreatAlertOverlay({
    super.key,
    required this.appName,
    required this.packageName,
    required this.similarity,
    required this.onDismiss,
  });

  final String appName;
  final String packageName;
  final double similarity;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A0000),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.report_problem_rounded,
                    color: K.danger,
                    size: 100,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'CRITICAL THREAT DETECTED',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: K.danger,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KAVACH has identified a malicious application impersonating State Bank of India.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 16,
                      color: K.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Risk Score',
                              style: GoogleFonts.rajdhani(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: K.textPrimary,
                              ),
                            ),
                            Text(
                              '${(similarity * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.dmMono(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: K.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: similarity,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(K.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: K.danger.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        _infoRow('APP', appName),
                        const SizedBox(height: 12),
                        _infoRow('PACKAGE', packageName),
                        const SizedBox(height: 12),
                        _infoRow('VERDICT', 'MALICIOUS (FAKE YONO)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'UNINSTALL THIS APP IMMEDIATELY TO PROTECT YOUR BANK ACCOUNT.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: K.danger,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: K.danger,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: K.danger.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        NativeBridge.openAppUninstall(packageName);
                      },
                      icon: const Icon(Icons.delete_forever),
                      label: Text(
                        'UNINSTALL MALICIOUS APP NOW',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: K.textMuted.withValues(alpha: 0.3)),
                        foregroundColor: K.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onDismiss,
                      child: Text(
                        'I UNDERSTAND, TAKE ME BACK',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmMono(
            fontSize: 11,
            color: K.textMuted,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 11,
            color: K.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
