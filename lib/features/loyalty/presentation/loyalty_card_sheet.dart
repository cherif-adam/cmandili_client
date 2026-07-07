import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../orders/data/models/order.dart';
import '../../orders/providers/order_provider.dart';
import '../data/loyalty_eligibility.dart';
import 'loyalty_rewards_screen.dart';
import 'widgets/loyalty_progress_section.dart';
import 'widgets/loyalty_stamp.dart';
import 'widgets/loyalty_stamp_grid.dart';

/// Post-order-placement "Carte de fidélité" bottom sheet.
///
/// Purely additive/cosmetic: it never writes anything, it only reads the
/// customer's existing confirmed delivered-count and projects one extra
/// "pending" stamp for the order that was just placed (there is no
/// server-side pending-points concept — see 20260706171000_loyalty_program.sql,
/// which only counts on the `delivered` transition).
class LoyaltyCardSheet extends ConsumerStatefulWidget {
  final String orderId;
  final int initialConfirmedCount;

  const LoyaltyCardSheet({
    super.key,
    required this.orderId,
    required this.initialConfirmedCount,
  });

  /// Fetches the customer's loyalty progress and shows the sheet — or does
  /// nothing at all if the order isn't loyalty-eligible or the fetch fails.
  /// Must never throw and must never delay the caller's own navigation.
  static Future<void> maybeShow(
    BuildContext context, {
    required WidgetRef ref,
    required Order order,
  }) async {
    if (!kLoyaltyEligibleOrderTypes.contains(order.type)) return;
    if (order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled) return;

    try {
      final count = await ref.read(orderRepositoryProvider).getLoyaltyDeliveredCount();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.loyaltySheetBarrier,
        builder: (_) => LoyaltyCardSheet(orderId: order.id, initialConfirmedCount: count),
      );
    } catch (_) {
      // Fail silently — the order flow must never be interrupted by this.
    }
  }

  @override
  ConsumerState<LoyaltyCardSheet> createState() => _LoyaltyCardSheetState();
}

class _LoyaltyCardSheetState extends ConsumerState<LoyaltyCardSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<Offset> _slide;

  // Position (0..9) in the current cycle BEFORE today's order, and what it
  // becomes once today's order is counted (1..10). 10 means today's order IS
  // the free-delivery milestone, which also ends the cycle.
  late final int _m;
  late final int _positionAfterToday;

  bool _impactDone = false;
  bool _delivered = false;
  bool _cycleReset = false;

  @override
  void initState() {
    super.initState();
    _m = loyaltyCyclePosition(widget.initialConfirmedCount);
    _positionAfterToday = _m + 1;
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _handleImpactComplete() {
    setState(() => _impactDone = true);
    if (_positionAfterToday == kLoyaltyTotalSlots) {
      // Brief celebratory pause showing the completed 10/10 card before the
      // new cycle starts.
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _cycleReset = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(orderStreamProvider(widget.orderId), (previous, next) {
      final order = next.valueOrNull;
      if (order != null && order.status == OrderStatus.delivered && !_delivered) {
        setState(() => _delivered = true);
      }
    });

    final l10n = AppLocalizations.of(context)!;
    const threshold = kLoyaltyTotalSlots;

    final String progressText;
    if (_cycleReset) {
      progressText = l10n.loyaltyRemainingHalf(5);
    } else if (_positionAfterToday == 5) {
      progressText = l10n.loyaltyCelebrationHalf;
    } else if (_positionAfterToday == threshold) {
      progressText = l10n.loyaltyCelebrationFree;
    } else if (_positionAfterToday < 5) {
      progressText = l10n.loyaltyRemainingHalf(5 - _positionAfterToday);
    } else {
      progressText = l10n.loyaltyRemainingFree(threshold - _positionAfterToday);
    }

    final earnedCountForGrid = _cycleReset ? 0 : _m;
    final specialIndexForGrid = _cycleReset ? null : _m;
    final specialStateForGrid =
        _delivered ? LoyaltyStampState.earned : LoyaltyStampState.pending;
    final displayedFilled = _cycleReset ? 0 : (_m + (_impactDone ? 1 : 0));

    return SlideTransition(
      position: _slide,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              gradient: AppColors.loyaltyHeaderGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.loyaltyDecorCircleAmber,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.loyaltyDecorCircleWhite,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _TitleRow(l10n: l10n),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: LoyaltyStampGrid(
                        earnedCount: earnedCountForGrid,
                        totalSlots: threshold,
                        specialIndex: specialIndexForGrid,
                        specialState: specialStateForGrid,
                        staggerIn: true,
                        animateImpact: true,
                        onImpactComplete: _handleImpactComplete,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LoyaltyProgressSection(
                      l10n: l10n,
                      filled: displayedFilled,
                      total: threshold,
                      remainingText: progressText,
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(
                      label: l10n.loyaltyViewRewards,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoyaltyRewardsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final AppLocalizations l10n;
  const _TitleRow({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          padding: const EdgeInsets.all(6),
          child: ClipOval(
            child: Image.asset('assets/images/logo_client.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.loyaltyCardTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: AppColors.loyaltyPendingSubtitleColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.loyaltyPendingSubtitle,
                      style: const TextStyle(
                        color: AppColors.loyaltyPendingSubtitleColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.loyaltyButtonGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
