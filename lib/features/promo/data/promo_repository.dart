import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/promo_code_response.dart';

/// Thin wrapper around the `apply_promo_code` Supabase RPC.
///
/// Two public methods share the same server function; they differ only in the
/// `p_dry_run` flag they pass:
///
///   [validatePromoCode] — dry run, no DB writes.
///   Call this when the user taps "Apply" to show the discount preview
///   without permanently consuming the code.
///
///   [applyPromoCode] — commits usage + increments used_count.
///   Call this exactly once inside _placeOrder(), AFTER all other
///   validations have passed, using the server-returned new_subtotal.
///
/// SECURITY NOTE: The discount calculation is performed entirely inside the
/// PL/pgSQL function.  This class never computes or adjusts any price.
class PromoRepository {
  final _supabase = Supabase.instance.client;

  /// Preview-only. Validates the code against all rules but does NOT write
  /// to user_promo_usages or increment used_count.
  Future<PromoCodeResponse> validatePromoCode({
    required String promoCode,
    required double subtotal,
  }) =>
      _call(promoCode: promoCode, subtotal: subtotal, dryRun: true);

  /// Commit path. Validates + locks the row + records usage + increments
  /// used_count atomically. Call this once at order-placement time.
  Future<PromoCodeResponse> applyPromoCode({
    required String promoCode,
    required double subtotal,
  }) =>
      _call(promoCode: promoCode, subtotal: subtotal, dryRun: false);

  // ── Private ───────────────────────────────────────────────────────────────

  Future<PromoCodeResponse> _call({
    required String promoCode,
    required double subtotal,
    required bool dryRun,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return PromoCodeResponse.localError('Vous devez être connecté pour utiliser un code promo');
    }

    try {
      final result = await _supabase.rpc(
        'apply_promo_code',
        params: {
          'p_user_id':    userId,
          'p_promo_code': promoCode,
          'p_subtotal':   subtotal,
          'p_dry_run':    dryRun,
        },
      );

      // The RPC always returns a single JSONB object.
      return PromoCodeResponse.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e) {
      debugPrint('PromoRepository error (dryRun=$dryRun): $e');
      return PromoCodeResponse.localError(
        'Erreur réseau. Veuillez réessayer.',
      );
    }
  }
}
