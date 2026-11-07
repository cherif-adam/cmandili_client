import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The assistant's face: a white chat bubble with two violet eyes that blink
/// now and then, and a small ✦ at its corner that twinkles between blinks.
/// Built with Flutter animations only (no Lottie asset in the project).
/// Static, eyes open, when [animate] is false (reduced motion).
class LivingAiIcon extends StatefulWidget {
  const LivingAiIcon({
    super.key,
    this.size = 24,
    this.animate = true,
    this.period = const Duration(milliseconds: 4200),
  });

  final double size;
  final bool animate;
  final Duration period;

  @override
  State<LivingAiIcon> createState() => _LivingAiIconState();
}

class _LivingAiIconState extends State<LivingAiIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  // Eyes: open, a quick blink at the start of each period.
  static final _eyeOpen = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.12), weight: 3),
    TweenSequenceItem(tween: Tween(begin: 0.12, end: 1.0), weight: 3),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 94),
  ]);

  // Sparkle: rests, then a short twinkle half-way through.
  static final _sparkle = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 48),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 7),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 9),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 36),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(LivingAiIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0.5; // eyes open, sparkle at rest
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final eye = s * 0.14;
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final open = widget.animate ? _eyeOpen.evaluate(_controller) : 1.0;
            final twinkle = widget.animate ? _sparkle.evaluate(_controller) : 1.0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.chat_bubble_rounded, size: s, color: Colors.white),
                // The bubble's body sits in the upper part of the glyph
                // (its tail is at the bottom), so the eyes do too.
                Positioned(
                  left: 0,
                  right: 0,
                  top: s * 0.40 - eye / 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Eye(size: eye, open: open),
                      SizedBox(width: s * 0.17),
                      _Eye(size: eye, open: open),
                    ],
                  ),
                ),
                Positioned(
                  right: -s * 0.30,
                  top: -s * 0.30,
                  child: Transform.scale(
                    scale: twinkle,
                    child: Icon(Icons.auto_awesome_rounded, size: s * 0.52, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.size, required this.open});

  final double size;
  final double open;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: size,
          height: size * open,
          decoration: BoxDecoration(
            color: AppColors.aiViolet,
            borderRadius: BorderRadius.circular(size),
          ),
        ),
      ),
    );
  }
}
