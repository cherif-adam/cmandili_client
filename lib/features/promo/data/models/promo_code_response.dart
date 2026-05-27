/// Response model for the `apply_promo_code` Supabase RPC.
///
/// The RPC always returns a JSONB object with the same top-level keys
/// regardless of whether the call was a dry-run preview or a commit.
/// This model maps that contract to a typed Dart class.
///
/// On success:
///   status          = 'success'
///   discountAmount  > 0
///   newSubtotal     = original subtotal − discountAmount  (≥ 0)
///
/// On failure:
///   status          = 'error'
///   errorCode       = one of the error codes below
///   errorMessage    = human-readable French message
///   discountAmount  = 0
///   newSubtotal     = null
class PromoCodeResponse {
  final bool isSuccess;

  /// Machine-readable error tag. One of:
  ///   INVALID_CODE | NOT_FOUND | INACTIVE | EXPIRED |
  ///   MAX_USES_REACHED | ALREADY_USED | MIN_ORDER | LOCAL_ERROR
  final String? errorCode;

  /// French message ready to display directly in a SnackBar / badge.
  final String? errorMessage;

  /// How much was (or will be) discounted from the subtotal.
  /// Always ≥ 0.  Zero when [isSuccess] is false.
  final double discountAmount;

  /// The subtotal after the discount has been applied.
  /// null when [isSuccess] is false.
  final double? newSubtotal;

  const PromoCodeResponse({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    this.discountAmount = 0.0,
    this.newSubtotal,
  });

  // ── Factory constructors ─────────────────────────────────────────────────

  factory PromoCodeResponse.fromJson(Map<String, dynamic> json) {
    final success = (json['status'] as String?) == 'success';
    return PromoCodeResponse(
      isSuccess: success,
      errorCode: json['error_code'] as String?,
      // Prefer the DB message (already French); fall back to our local map.
      errorMessage: success
          ? null
          : _localizedError(
              json['error_code'] as String?,
              json['error_message'] as String?,
            ),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      newSubtotal: (json['new_subtotal'] as num?)?.toDouble(),
    );
  }

  /// Convenience constructor for errors that never reach the server
  /// (no auth session, network failure, etc.).
  factory PromoCodeResponse.localError(String message) {
    return PromoCodeResponse(
      isSuccess: false,
      errorCode: 'LOCAL_ERROR',
      errorMessage: message,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns a French error string.  The DB already returns well-formed
  /// French messages for most codes; this map is a safety net for any code
  /// that doesn't carry a message (e.g. future additions).
  static String _localizedError(String? code, String? dbMessage) {
    if (dbMessage != null && dbMessage.isNotEmpty) return dbMessage;
    switch (code) {
      case 'INVALID_CODE':
        return 'Code invalide';
      case 'NOT_FOUND':
        return 'Ce code promo n\'existe pas';
      case 'INACTIVE':
        return 'Ce code promo n\'est plus actif';
      case 'EXPIRED':
        return 'Ce code a expiré';
      case 'MAX_USES_REACHED':
        return 'Ce code n\'est plus disponible';
      case 'ALREADY_USED':
        return 'Vous avez déjà utilisé ce code promo';
      case 'MIN_ORDER':
        return 'Montant minimum non atteint';
      default:
        return 'Code invalide ou expiré';
    }
  }
}
