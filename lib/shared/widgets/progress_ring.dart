import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A minimal circular progress ring with a center label.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 96,
    this.strokeWidth = 8,
    this.color = AppColors.indigo500,
    this.trackColor,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress, strokeWidth, color, trackColor),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.strokeWidth, this.color, this.trackColor);

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor ?? color.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final foreground = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963,
      6.2831853 * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
