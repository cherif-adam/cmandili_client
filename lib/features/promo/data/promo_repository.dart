import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart/data/models/cart_item.dart';
import 'models/promo_code_response.dart';
import 'promo_cart_lines.dart';

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
/// SÉCURITÉ. Cette classe n'envoie AUCUN prix — seulement les lignes du
/// panier : identifiants, quantités, variante et suppléments. Le serveur
/// relit chaque prix dans `vendor_items`, calcule le sous-total lui-même et
/// n'accorde la remise qu'aux articles sans promotion en cours.
///
/// La version précédente passait `p_subtotal`, un nombre que le serveur
/// utilisait tel quel : son propre commentaire annonçait « the frontend NEVER
/// computes the discounted price », ce qui était vrai de la REMISE mais pas
/// du MONTANT sur lequel elle portait. Cette signature n'est plus accessible
/// aux clients (REVOKE, migration 20260929100000).
class PromoRepository {
  final _supabase = Supabase.instance.client;

  /// Preview-only. Validates the code against all rules but does NOT write
  /// to user_promo_usages or increment used_count.
  Future<PromoCodeResponse> validatePromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) =>
      _call(promoCode: promoCode, items: items, dryRun: true);

  /// Commit path. Validates + locks the row + records usage + increments
  /// used_count atomically. Call this once at order-placement time.
  Future<PromoCodeResponse> applyPromoCode({
    required String promoCode,
    required List<CartItem> items,
  }) =>
      _call(promoCode: promoCode, items: items, dryRun: false);

  /// Undo a committed [applyPromoCode] call. Callers MUST invoke this if
  /// order creation or payment fails after a successful applyPromoCode —
  /// otherwise the customer permanently loses the usage (and, for
  /// single-use/capped codes, the code itself) with no order to show for
  /// it. Best-effort: swallows errors since this already runs inside a
  /// failure-handling path and the release itself is not user-blocking.
  Future<void> releaseUsage({required String promoCode}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.rpc(
        'release_promo_usage',
        params: {'p_user_id': userId, 'p_promo_code': promoCode},
      );
    } catch (e) {
      debugPrint('PromoRepository.releaseUsage error: $e');
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<PromoCodeResponse> _call({
    required String promoCode,
    required List<CartItem> items,
    required bool dryRun,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      // Traduit à l'affichage par promoErrorText, via ce code d'erreur.
      return PromoCodeResponse.serverCode('NOT_AUTHENTICATED');
    }
    if (items.isEmpty) {
      return PromoCodeResponse.serverCode('EMPTY_CART');
    }

    try {
      final result = await _supabase.rpc(
        'apply_promo_code',
        params: {
          'p_user_id':    userId,
          'p_promo_code': promoCode,
          // `p_items` et non `p_surtotal` : c'est le nom d'argument qui
          // choisit la surcharge PostgREST, donc ce qui garantit qu'on
          // n'appelle plus l'ancienne fonction.
          'p_items':      promoCartLines(items),
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
