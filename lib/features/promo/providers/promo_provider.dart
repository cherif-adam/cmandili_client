import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/data/models/cart_item.dart';
import '../data/promo_repository.dart';
import '../data/models/promo_code_response.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final promoRepositoryProvider = Provider<PromoRepository>(
  (_) => PromoRepository(),
);

// ── State ─────────────────────────────────────────────────────────────────────

enum PromoStatus {
  /// No code entered yet / code has been removed.
  idle,

  /// Waiting for the RPC to respond.
  loading,

  /// RPC responded with status = 'success'.
  success,

  /// RPC responded with status = 'error', or a network failure occurred.
  error,
}

class PromoState {
  /// The code that was last sent to the server (uppercased, trimmed).
  /// Empty string when status == idle.
  final String appliedCode;

  final PromoStatus status;

  /// Full RPC response; null while idle or loading.
  final PromoCodeResponse? response;

  const PromoState({
    this.appliedCode = '',
    this.status = PromoStatus.idle,
    this.response,
  });

  // ── Convenience getters ──────────────────────────────────────────────────

  /// True when a code has been verified and a discount is ready to display.
  bool get isApplied =>
      status == PromoStatus.success && (response?.isSuccess ?? false);

  /// Discount amount as reported by the server.  Zero when not applied.
  double get discountAmount => response?.discountAmount ?? 0.0;

  /// Faut-il préciser sur quelle part la remise a porté ?
  ///
  /// Seulement quand une partie du panier est déjà en promotion. Écrire
  /// « sur 12.000 DT éligibles » alors que TOUT l'est ajouterait un chiffre
  /// qui n'apprend rien et ferait douter d'une exclusion invisible.
  bool get showsEligibleBreakdown {
    final r = response;
    if (r == null || !r.isSuccess || !r.hasEligibleBreakdown) return false;
    // Un millime d'écart d'arrondi ne fait pas une part non éligible.
    return (r.computedSubtotal! - r.eligibleSubtotal!).abs() > 0.001;
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  PromoState copyWith({
    String? appliedCode,
    PromoStatus? status,
    PromoCodeResponse? response,
  }) {
    return PromoState(
      appliedCode: appliedCode ?? this.appliedCode,
      status: status ?? this.status,
      response: response ?? this.response,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PromoNotifier extends StateNotifier<PromoState> {
  final PromoRepository _repo;

  PromoNotifier(this._repo) : super(const PromoState());

  /// Vérification à blanc : montre l'aperçu de la remise sans consommer le
  /// code.
  ///
  /// Reçoit les LIGNES du panier, plus un sous-total. C'est le serveur qui
  /// calcule le montant, à partir des prix qu'il relit lui-même.
  Future<void> validate(String code, List<CartItem> items) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = const PromoState();
      return;
    }

    state = PromoState(
      appliedCode: trimmed.toUpperCase(),
      status: PromoStatus.loading,
    );

    final response = await _repo.validatePromoCode(
      promoCode: trimmed,
      items: items,
    );

    state = PromoState(
      appliedCode: trimmed.toUpperCase(),
      status: response.isSuccess ? PromoStatus.success : PromoStatus.error,
      response: response,
    );
  }

  /// Clears the promo state.  Called when the user taps "Remove" or when
  /// the cart changes (subtotal changes invalidate the preview).
  void reset() => state = const PromoState();
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// autoDispose ensures the promo state is cleared when the checkout screen
/// is popped, so stale validation results never carry over.
final promoProvider =
    StateNotifierProvider.autoDispose<PromoNotifier, PromoState>(
  (ref) => PromoNotifier(ref.read(promoRepositoryProvider)),
);
