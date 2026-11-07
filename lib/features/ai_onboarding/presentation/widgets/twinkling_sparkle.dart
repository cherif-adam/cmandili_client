import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The ✦ of the AI features, in the AI gradient. Every [period] it does a
/// short, subtle twinkle (a little bigger, a slight turn, back) and rests the
/// rest of the time. Static when [animate] is false (reduced motion).
class TwinklingSparkle extends StatefulWidget {
  const TwinklingSparkle({
    super.key,
    required this.size,
    this.animate = true,
    this.period = const Duration(seconds: 5),
  });

  final double size;
  final bool animate;
  final Duration period;

  @override
  State<TwinklingSparkle> createState() => _TwinklingSparkleState();
}

class _TwinklingSparkleState extends State<TwinklingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  // The twinkle takes the first 14 % of the period (0.7 s of 5 s).
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 6),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 8),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 86),
  ]);
  static final _turn = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: math.pi / 10).chain(CurveTween(curve: Curves.easeOut)), weight: 6),
    TweenSequenceItem(tween: Tween(begin: math.pi / 10, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 8),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 86),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(TwinklingSparkle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
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
    final icon = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.aiGradient.createShader(bounds),
      child: Icon(Icons.auto_awesome_rounded, size: widget.size, color: Colors.white),
    );
    if (!widget.animate) return icon;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: icon,
        builder: (context, child) => Transform.rotate(
          angle: _turn.evaluate(_controller),
          child: Transform.scale(scale: _scale.evaluate(_controller), child: child),
        ),
      ),
    );
  }
}
