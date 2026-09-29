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
  ///   MAX_USES_REACHED | ALREADY_USED | MIN_ORDER |
  ///   ALL_ITEMS_ON_PROMO | NOT_FIRST_ORDER | EMPTY_CART |
  ///   NOT_AUTHENTICATED | LOCAL_ERROR
  ///
  /// C'est LUI qu'on traduit (promoErrorText), pas [errorMessage].
  final String? errorCode;

  /// Message brut du serveur, EN FRANÇAIS. Ne pas l'afficher directement :
  /// passer par promoErrorText(), qui traduit [errorCode] dans la langue du
  /// client et ne retombe sur celui-ci que pour un code inconnu de cette
  /// version de l'application.
  final String? errorMessage;

  /// Sous-total recalculé PAR LE SERVEUR depuis `vendor_items`.
  ///
  /// L'application ne l'envoie plus, elle le reçoit. Un écart avec le total
  /// affiché signale que le panier a bougé entre l'affichage et l'appel —
  /// un prix changé, une promotion démarrée ou expirée.
  final double? computedSubtotal;

  /// La part du sous-total à laquelle le code s'applique : les articles SANS
  /// promotion en cours. Une promotion d'article est déjà le prix ; lui
  /// ajouter un code ferait −60 % là où le commerçant a accepté −50 %, et la
  /// commission serait calculée sur un montant qu'il n'a jamais consenti.
  final double? eligibleSubtotal;

  /// Montant minimum exigé par le code, quand le serveur le renvoie.
  /// Absent aujourd'hui : l'erreur MIN_ORDER reste alors générique.
  final double? minOrderAmount;

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
    this.computedSubtotal,
    this.eligibleSubtotal,
    this.minOrderAmount,
  });

  /// Vrai quand le serveur a su dire sur quelle part le code a porté, donc
  /// quand l'écran peut afficher « − 3.500 DT sur 12.000 DT éligibles ».
  bool get hasEligibleBreakdown =>
      eligibleSubtotal != null && computedSubtotal != null;

  // ── Factory constructors ─────────────────────────────────────────────────

  factory PromoCodeResponse.fromJson(Map<String, dynamic> json) {
    final success = (json['status'] as String?) == 'success';
    return PromoCodeResponse(
      isSuccess: success,
      errorCode: json['error_code'] as String?,
      errorMessage: success ? null : json['error_message'] as String?,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      newSubtotal: (json['new_subtotal'] as num?)?.toDouble(),
      computedSubtotal: (json['computed_subtotal'] as num?)?.toDouble(),
      eligibleSubtotal: (json['eligible_subtotal'] as num?)?.toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
    );
  }

  /// Erreur qui n'atteint jamais le serveur — panne réseau, par exemple.
  /// Le message est déjà dans la langue du client, il passe tel quel.
  factory PromoCodeResponse.localError(String message) {
    return PromoCodeResponse(
      isSuccess: false,
      errorCode: 'LOCAL_ERROR',
      errorMessage: message,
    );
  }

  /// Erreur que l'application détecte elle-même mais qui porte un code du
  /// serveur, pour être traduite au même endroit que les autres.
  factory PromoCodeResponse.serverCode(String code) {
    return PromoCodeResponse(isSuccess: false, errorCode: code);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

}
