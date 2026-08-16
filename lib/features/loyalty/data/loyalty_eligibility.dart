import 'package:supabase_flutter/supabase_flutter.dart';
import '../../orders/data/models/order.dart';

/// Order types the loyalty program counts, mirroring
/// `apply_loyalty_at_checkout()` in `20260814090000_loyalty_at_checkout.sql`
/// exactly (supermarket and the dead billPayment type never count).
const kLoyaltyEligibleOrderTypes = {OrderType.food, OrderType.courier, OrderType.facture};

/// Stamp slots per card cycle (matches the backend: half-discount at every
/// 5th delivered order, free delivery at every 10th).
const kLoyaltyTotalSlots = 10;

/// Position within the current 10-order cycle (0..9). `delivered_count` in
/// `loyalty_customer_progress` is a lifetime counter that never resets in
/// storage — the milestone trigger re-fires every 5th/10th forever via
/// `% 5` / `% 10`, and the client derives the same cyclical "position on the
/// card" the same way, on read, without needing the stored value to reset.
int loyaltyCyclePosition(int confirmedCount) => confirmedCount % kLoyaltyTotalSlots;

/// A client-side PREVIEW of the discount on the customer's next order —
/// used only to render an estimate at checkout, before the order exists.
/// NOT authoritative: `apply_loyalty_at_checkout()` (the BEFORE INSERT
/// trigger on `orders`) makes the real, enforced determination at creation
/// time, so a stale/wrong preview here (e.g. a race with another order
/// placed seconds earlier) can never result in an incorrect charge — it can
/// only make the estimate shown before that moment slightly off.
class LoyaltyMilestonePreview {
  final String type; // 'half' | 'free'
  final double discountMultiplier; // 0.5 | 1.0
  const LoyaltyMilestonePreview(this.type, this.discountMultiplier);
}

/// Predicts the milestone for whatever order the customer creates next, by
/// reading their current `loyalty_customer_progress.delivered_count` and
/// applying the same modulo logic as `apply_loyalty_at_checkout()`. Returns
/// null when signed out, on any read error, or when the next order isn't a
/// milestone.
Future<LoyaltyMilestonePreview?> predictNextOrderMilestone() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('loyalty_customer_progress')
        .select('delivered_count')
        .eq('customer_id', userId)
        .maybeSingle();
    final nextCount = ((row?['delivered_count'] as int?) ?? 0) + 1;
    if (nextCount % kLoyaltyTotalSlots == 0) {
      return const LoyaltyMilestonePreview('free', 1.0);
    }
    if (nextCount % 5 == 0) {
      return const LoyaltyMilestonePreview('half', 0.5);
    }
    return null;
  } catch (_) {
    return null;
  }
}
