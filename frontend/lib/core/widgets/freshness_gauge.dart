import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../utils/freshness.dart';

/// The single most important custom widget in the app (design system
/// section 5.3). Identical everywhere it appears: scan result, listing
/// card, listing detail. Never reimplement locally in a feature folder.
class FreshnessGaugePainter extends CustomPainter {
  const FreshnessGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FreshnessGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class FreshnessGauge extends StatelessWidget {
  const FreshnessGauge({super.key, required this.score, this.size = 96});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = freshnessColorFor(score, Theme.of(context).brightness);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: kFreshnessGaugeDuration,
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: FreshnessGaugePainter(
              progress: value,
              color: color,
              trackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
            ),
            child: Center(
              child: Text(
                '${(value * 100).round()}',
                style: TextStyle(
                  fontSize: size / 3.2,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
