import 'package:flutter/material.dart';
import 'loyalty_stamp.dart';

/// Lays out the loyalty stamp slots (default 5 columns x 2 rows) and
/// choreographs the shared "impact shake" that ripples through the whole
/// card when the special (pending) stamp lands.
///
/// [earnedCount] is the confirmed lifetime count (never includes the
/// in-flight order). [specialIndex]/[specialState] describe the one slot
/// that differs from the plain earned/empty pattern — either the just-placed
/// order's pending stamp (Part 1) or the just-cancelled order's removed
/// stamp (Part 2).
class LoyaltyStampGrid extends StatefulWidget {
  final int earnedCount;
  final int totalSlots;
  final int? specialIndex;
  final LoyaltyStampState specialState;
  final bool staggerIn;
  final bool animateImpact;
  final bool compact;
  final VoidCallback? onImpactComplete;

  const LoyaltyStampGrid({
    super.key,
    required this.earnedCount,
    this.totalSlots = 10,
    this.specialIndex,
    this.specialState = LoyaltyStampState.empty,
    this.staggerIn = false,
    this.animateImpact = false,
    this.compact = false,
    this.onImpactComplete,
  });

  @override
  State<LoyaltyStampGrid> createState() => _LoyaltyStampGridState();
}

class _LoyaltyStampGridState extends State<LoyaltyStampGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleImpactSettled() {
    _shakeController.forward(from: 0);
    widget.onImpactComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 30.0 : 44.0;
    final spacing = widget.compact ? 8.0 : 12.0;

    final stamps = List<Widget>.generate(widget.totalSlots, (i) {
      final isSpecial = widget.specialIndex == i;
      final state = isSpecial
          ? widget.specialState
          : (i < widget.earnedCount ? LoyaltyStampState.earned : LoyaltyStampState.empty);

      return LoyaltyStamp(
        key: ValueKey('loyalty_stamp_$i'),
        state: state,
        size: size,
        staggerDelay: (widget.staggerIn && state == LoyaltyStampState.earned)
            ? Duration(milliseconds: 40 * i)
            : null,
        playImpact: isSpecial && widget.animateImpact && state == LoyaltyStampState.pending,
        onImpactSettled: isSpecial ? _handleImpactSettled : null,
      );
    });

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(offset: Offset(0, _shake.value), child: child),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: stamps,
      ),
    );
  }
}
