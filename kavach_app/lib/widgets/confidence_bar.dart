import 'package:flutter/material.dart';

import '../constants.dart';

class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar(this.confidence, {super.key, this.height = 8});

  final double? confidence;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = ((confidence ?? 0).clamp(0.0, 1.0)) * 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: K.surface2),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [K.accent.withValues(alpha: 0.85), K.primary.withValues(alpha: 0.95)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
