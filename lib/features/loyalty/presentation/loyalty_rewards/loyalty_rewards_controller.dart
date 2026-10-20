import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/providers/order_provider.dart';
import '../../data/loyalty_eligibility.dart';

/// The rewards screen's logic: where the customer stands in the current
/// 10-order cycle (from [loyaltyProgressProvider]) and the retry.
final loyaltyRewardsControllerProvider =
    NotifierProvider.autoDispose<LoyaltyRewardsController, AsyncValue<LoyaltyCycle>>(
        LoyaltyRewardsController.new);

enum LoyaltyMilestoneState { achieved, current, locked }

/// The customer's place in the current cycle of [kLoyaltyTotalSlots] orders:
/// -50% on delivery at the 5th, free delivery at the 10th.
class LoyaltyCycle {
  /// Confirmed orders in the current cycle.
  final int position;

  const LoyaltyCycle(this.position);

  int get totalSlots => kLoyaltyTotalSlots;

  bool get halfAchieved => position >= 5;

  int get remainingToHalf => 5 - position;

  int get remainingToFree => kLoyaltyTotalSlots - position;

  LoyaltyMilestoneState get halfMilestone =>
      halfAchieved ? LoyaltyMilestoneState.achieved : LoyaltyMilestoneState.current;

  LoyaltyMilestoneState get freeMilestone =>
      halfAchieved ? LoyaltyMilestoneState.current : LoyaltyMilestoneState.locked;
}

class LoyaltyRewardsController extends AutoDisposeNotifier<AsyncValue<LoyaltyCycle>> {
  // ── State ─────────────────────────────────────────────────────────────────

  @override
  AsyncValue<LoyaltyCycle> build() => ref
      .watch(loyaltyProgressProvider)
      .whenData((confirmedCount) => LoyaltyCycle(loyaltyCyclePosition(confirmedCount)));

  // ── User actions ──────────────────────────────────────────────────────────

  void retry() => ref.invalidate(loyaltyProgressProvider);
}
