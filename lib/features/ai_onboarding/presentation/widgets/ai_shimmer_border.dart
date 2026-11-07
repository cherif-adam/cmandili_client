import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Draws, once, a band of the AI gradient travelling around [child]'s
/// rounded border, fading in and out. It plays when [play] turns true (or
/// is true when the widget appears), then calls [onPlayed]. Nothing is drawn
/// the rest of the time.
///
/// Only the border repaints (foreground painter inside a RepaintBoundary),
/// never the search field under it.
class AiShimmerBorder extends StatefulWidget {
  const AiShimmerBorder({
    super.key,
    required this.play,
    required this.borderRadius,
    required this.child,
    this.onPlayed,
    this.duration = const Duration(milliseconds: 1800),
    this.strokeWidth = 2.2,
  });

  final bool play;
  final double borderRadius;
  final Widget child;
  final VoidCallback? onPlayed;
  final Duration duration;
  final double strokeWidth;

  @override
  State<AiShimmerBorder> createState() => _AiShimmerBorderState();
}

class _AiShimmerBorderState extends State<AiShimmerBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onPlayed?.call();
        });

  @override
  void initState() {
    super.initState();
    if (widget.play) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(AiShimmerBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _controller.forward(from: 0);
    } else if (!widget.play && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _ShimmerPainter(
          progress: _controller,
          radius: widget.borderRadius,
          strokeWidth: widget.strokeWidth,
        ),
        child: widget.child,
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.progress,
    required this.radius,
    required this.strokeWidth,
  }) : super(repaint: progress);

  final AnimationController progress;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!progress.isAnimating) return;
    final t = progress.value;
    final opacity = math.sin(math.pi * t).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.aiViolet.withValues(alpha: opacity),
          AppColors.aiBlue.withValues(alpha: opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.10, 0.22, 0.32],
        transform: GradientRotation(2 * math.pi * t),
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
}
