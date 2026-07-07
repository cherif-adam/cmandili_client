import '../../orders/data/models/order.dart';

/// Order types the loyalty program counts, mirroring
/// `apply_loyalty_program()` in `20260706171000_loyalty_program.sql` exactly
/// (supermarket and the dead billPayment type never count).
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
