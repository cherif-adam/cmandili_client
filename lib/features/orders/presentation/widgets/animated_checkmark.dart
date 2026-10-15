import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// White-ringed circle with an emerald checkmark that draws itself as
/// [progress] animates from 0 to 1.
class AnimatedCheckmark extends AnimatedWidget {
  final double size;

  const AnimatedCheckmark({super.key, required Animation<double> progress, required this.size})
      : super(listenable: progress);

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CheckmarkPainter(progress: _progress.value),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;

  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, size.width / 2 - ringPaint.strokeWidth / 2, ringPaint);

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);

    final metrics = path.computeMetrics().first;
    final drawnPath = metrics.extractPath(0, metrics.length * progress);

    final checkPaint = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawnPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
