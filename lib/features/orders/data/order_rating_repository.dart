import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ratings of a delivered order: the shop, then the driver.
class OrderRatingRepository {
  final _supabase = Supabase.instance.client;

  /// Whether the customer has already rated this order. Used to gate the
  /// post-delivery rating prompt so it never reappears once submitted (the
  /// DB's own UNIQUE(order_id) + write-once RLS policy are the real
  /// enforcement — this is just what lets the UI decide whether to ask).
  Future<bool> hasRating(String orderId) async {
    final row = await _supabase
        .from('order_ratings')
        .select('id')
        .eq('order_id', orderId)
        .maybeSingle();
    return row != null;
  }

  /// Records a 1-5 star rating (+ optional comment) for a delivered food
  /// order. The DB trigger recomputes restaurants.rating/review_count from
  /// the full order_ratings set right after this insert — no client-side
  /// average to keep in sync. Returns false (instead of throwing) on any
  /// failure — RLS rejecting a stale/ineligible order, or a duplicate
  /// insert racing another device — since the caller only needs to know
  /// whether to show a confirmation or a generic retry message.
  Future<bool> submitRating({
    required String orderId,
    required String restaurantId,
    required int rating,
    String? comment,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabase.from('order_ratings').insert({
        'order_id': orderId,
        'user_id': userId,
        'restaurant_id': restaurantId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
      return true;
    } catch (e) {
      // Still reported to the user as a generic retry, but logged: a
      // swallowed error here hid an FK failure for every non-restaurant shop.
      debugPrint('submitRating failed: $e');
      return false;
    }
  }

  // ── Driver rating ─────────────────────────────────────────────────────────

  /// Whether the customer can still rate the driver of this order: true only
  /// when the check itself succeeds and finds no rating. False when one
  /// exists, and false on any error (driver_ratings not created yet), so the
  /// prompt never appears for something that could not be saved.
  Future<bool> canRateDriver(String orderId) async {
    try {
      final row = await _supabase
          .from('driver_ratings')
          .select('id')
          .eq('order_id', orderId)
          .maybeSingle();
      return row == null;
    } catch (e) {
      return false;
    }
  }

  /// Records a 1-5 star rating (+ optional comment) for the driver who
  /// delivered [orderId]. A database trigger keeps the driver's average and
  /// count up to date. Returns false on any failure.
  Future<bool> submitDriverRating({
    required String orderId,
    required String driverId,
    required int rating,
    String? comment,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      await _supabase.from('driver_ratings').insert({
        'order_id': orderId,
        'driver_id': driverId,
        'user_id': userId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('submitDriverRating failed: $e');
      return false;
    }
  }
}
