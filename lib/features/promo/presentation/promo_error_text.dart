import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/utils/currency_formatter.dart';
import '../data/models/promo_code_response.dart';

/// Le message d'erreur d'un code promo, dans la langue du client.
///
/// Le serveur renvoie ses messages EN FRANÇAIS, en dur. Les afficher tels
/// quels donnait une phrase française à un client arabophone au milieu d'un
/// écran arabe. Le code d'erreur, lui, est une étiquette stable : c'est lui
/// qu'on traduit ici, et le message du serveur ne sert plus que de dernier
/// recours pour un code apparu côté base mais pas encore côté application.
String promoErrorText(AppLocalizations l, PromoCodeResponse response) {
  switch (response.errorCode) {
    case 'NOT_FOUND':
    case 'INVALID_CODE':
      return l.promoErrorNotFound;
    case 'INACTIVE':
      return l.promoErrorInactive;
    case 'EXPIRED':
      return l.promoErrorExpired;
    case 'MAX_USES_REACHED':
      return l.promoErrorMaxUses;
    case 'ALREADY_USED':
      return l.promoErrorAlreadyUsed;
    case 'MIN_ORDER':
      // Le montant n'est renvoyé que si la base le fournit. Sans lui, la
      // phrase reste juste mais vague — mieux que d'inventer un chiffre.
      final min = response.minOrderAmount;
      return min == null
          ? l.promoErrorMinOrder
          : l.promoErrorMinOrderAmount(CurrencyFormatter.formatPrice(min));
    case 'ALL_ITEMS_ON_PROMO':
      return l.promoErrorAllOnPromo;
    case 'NOT_FIRST_ORDER':
      return l.promoErrorNotFirstOrder;
    case 'EMPTY_CART':
      return l.promoErrorEmptyCart;
    case 'NOT_AUTHENTICATED':
      return l.promoErrorNotLoggedIn;
    case 'LOCAL_ERROR':
      return response.errorMessage ?? l.promoErrorNetwork;
    default:
      final fallback = response.errorMessage;
      return (fallback == null || fallback.isEmpty)
          ? l.promoErrorGeneric
          : fallback;
  }
}
