import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

enum LoyaltyStampState { earned, pending, empty, removed }

/// A single slot in the loyalty stamp grid.
///
/// Handles its own transition animations so the grid can just declare the
/// desired [state] per rebuild:
///  - [staggerDelay] set → fades+scales in once on first mount (used for the
///    already-earned stamps when the card first appears).
///  - [playImpact] true → the "rubber stamp" slam-down entrance for a
///    freshly-earned pending stamp (scale/rotation/opacity + haptic + ink
///    ripple), firing [onImpactSettled] once the slam itself has landed.
///  - Any other state change (e.g. pending → earned on live delivery, or
///    removed → empty after the cancellation hold) simply cross-fades via
///    [AnimatedSwitcher].
class LoyaltyStamp extends StatefulWidget {
  final LoyaltyStampState state;
  final double size;
  final Duration? staggerDelay;
  final bool playImpact;
  final VoidCallback? onImpactSettled;

  const LoyaltyStamp({
    super.key,
    required this.state,
    this.size = 44,
    this.staggerDelay,
    this.playImpact = false,
    this.onImpactSettled,
  });

  @override
  State<LoyaltyStamp> createState() => _LoyaltyStampState();
}

class _LoyaltyStampState extends State<LoyaltyStamp>
    with TickerProviderStateMixin {
  static const _restTilt = -0.2094; // ~-12deg, permanent "rubber stamp" tilt

  late final AnimationController _entrance;
  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;

  AnimationController? _impactController;
  Animation<double>? _impactScale;
  Animation<double>? _impactRotation;
  Animation<double>? _impactOpacity;

  AnimationController? _rippleController;
  Animation<double>? _rippleRadius;
  Animation<double>? _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _entranceOpacity = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceScale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));

    if (widget.playImpact) {
      _startImpact();
    } else if (widget.staggerDelay != null) {
      Future.delayed(widget.staggerDelay!, () {
        if (mounted) _entrance.forward();
      });
    } else {
      _entrance.value = 1;
    }
  }

  void _startImpact() {
    _impactController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _impactScale = Tween<double>(begin: 2.5, end: 1.0).animate(
      CurvedAnimation(parent: _impactController!, curve: Curves.easeOutBack),
    );
    _impactRotation = Tween<double>(begin: 0.38, end: 0.0).animate(
      CurvedAnimation(parent: _impactController!, curve: Curves.easeOutBack),
    );
    _impactOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _impactController!, curve: const Interval(0, 0.4)),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _rippleRadius = Tween<double>(begin: 0.5, end: 1.6)
        .animate(CurvedAnimation(parent: _rippleController!, curve: Curves.easeOut));
    _rippleOpacity = Tween<double>(begin: 0.6, end: 0.0)
        .animate(CurvedAnimation(parent: _rippleController!, curve: Curves.easeOut));

    _entrance.value = 1;
    _impactController!.forward().whenComplete(() {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onImpactSettled?.call();
      _rippleController!.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _impactController?.dispose();
    _rippleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget stamp = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(widget.state),
        child: _buildCircle(),
      ),
    );

    if (_impactController != null) {
      stamp = AnimatedBuilder(
        animation: Listenable.merge([_impactController!, _rippleController!]),
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_rippleController!.value > 0)
              Opacity(
                opacity: _rippleOpacity!.value,
                child: Container(
                  width: widget.size * _rippleRadius!.value,
                  height: widget.size * _rippleRadius!.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.loyaltyStampPendingBorder, width: 1.5),
                  ),
                ),
              ),
            Opacity(
              opacity: _impactOpacity!.value,
              child: Transform.rotate(
                angle: _impactRotation!.value,
                child: Transform.scale(scale: _impactScale!.value, child: child),
              ),
            ),
          ],
        ),
        child: stamp,
      );
    }

    return FadeTransition(
      opacity: _entranceOpacity,
      child: ScaleTransition(scale: _entranceScale, child: stamp),
    );
  }

  Widget _buildCircle() {
    switch (widget.state) {
      case LoyaltyStampState.earned:
        return _solidCircle(
          bg: AppColors.loyaltyStampEarnedBg,
          border: AppColors.loyaltyStampEarnedBorder,
          child: _mark(),
        );
      case LoyaltyStampState.pending:
        return _solidCircle(
          bg: AppColors.loyaltyStampPendingBg,
          border: AppColors.loyaltyStampPendingBorder,
          child: _mark(),
        );
      case LoyaltyStampState.removed:
        return _dashedCircle(
          bg: AppColors.loyaltyStampRemovedBg,
          border: AppColors.loyaltyStampRemovedBorder,
          child: Icon(Icons.close, size: widget.size * 0.4, color: AppColors.loyaltyStampRemovedBorder),
        );
      case LoyaltyStampState.empty:
        return _dashedCircle(border: AppColors.loyaltyStampEmptyBorder);
    }
  }

  Widget _mark() => Transform.rotate(
        angle: _restTilt,
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo_client.png',
            width: widget.size * 0.62,
            height: widget.size * 0.62,
            fit: BoxFit.cover,
          ),
        ),
      );

  Widget _solidCircle({required Color bg, required Color border, Widget? child}) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border, width: 2),
      ),
      child: Center(child: child),
    );
  }

  Widget _dashedCircle({Color bg = Colors.white, required Color border, Widget? child}) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: border),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 16;
    const gapFraction = 0.5;
    const sweepPerDash = (2 * 3.14159265) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      final start = i * sweepPerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweepPerDash * (1 - gapFraction),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => oldDelegate.color != color;
}
