import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A soft violet ring growing out of [child] and fading, [cycles] times,
/// then nothing. It plays when [play] turns true (or is true when the widget
/// appears), then calls [onDone]. The ring follows [child]'s pill shape, so
/// it fits the extended button as well as the round one.
class AiPulseHalo extends StatefulWidget {
  const AiPulseHalo({
    super.key,
    required this.play,
    required this.child,
    this.onDone,
    this.cycles = 3,
    this.cycle = const Duration(milliseconds: 1400),
    this.spread = 18,
  });

  final bool play;
  final Widget child;
  final VoidCallback? onDone;
  final int cycles;
  final Duration cycle;

  /// How far the ring travels past the button's edge, in logical pixels.
  final double spread;

  @override
  State<AiPulseHalo> createState() => _AiPulseHaloState();
}

class _AiPulseHaloState extends State<AiPulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.cycle);

  @override
  void initState() {
    super.initState();
    if (widget.play) _start();
  }

  @override
  void didUpdateWidget(AiPulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _start();
    } else if (!widget.play && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  void _start() {
    _controller.repeat(count: widget.cycles).whenComplete(() {
      if (!mounted) return;
      _controller.value = 0;
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HaloPainter(progress: _controller, spread: widget.spread),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.progress, required this.spread})
      : super(repaint: progress);

  final AnimationController progress;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    if (!progress.isAnimating) return;
    final t = Curves.easeOut.transform(progress.value);
    final grow = spread * t;
    final rect = (Offset.zero & size).inflate(grow);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 3 * (1 - t)
      ..color = AppColors.aiViolet.withValues(alpha: 0.45 * (1 - t));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) => oldDelegate.spread != spread;
}
