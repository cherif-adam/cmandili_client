import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../data/models/order.dart';

/// Le statut d'une commande, dans la langue du client.
///
/// `Order.getStatusText()` renvoyait des chaînes anglaises écrites en dur —
/// « Pending », « Preparing » — affichées telles quelles en haut de l'écran de
/// suivi, quelle que soit la langue choisie. Le modèle n'a pas accès aux
/// traductions ; c'est donc ici, au plus près de l'affichage, que le statut
/// devient du texte.
String orderStatusLabel(AppLocalizations l, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return l.orderStatusPending;
    case OrderStatus.confirmed:
      return l.orderStatusConfirmed;
    case OrderStatus.preparing:
      return l.orderStatusPreparing;
    case OrderStatus.ready:
      return l.orderStatusReady;
    case OrderStatus.pickedUp:
      return l.orderStatusPickedUp;
    case OrderStatus.onTheWay:
      return l.orderStatusOnTheWay;
    case OrderStatus.delivered:
      return l.orderStatusDelivered;
    case OrderStatus.cancelled:
      return l.orderStatusCancelled;
  }
}

/// Le moyen de paiement, dans la langue du client.
///
/// `orders.payment_method` stocke une clé technique — « cash » — que l'écran
/// affichait brute, en minuscules et en anglais, sous le total.
String paymentMethodLabel(AppLocalizations l, String raw) {
  switch (raw.toLowerCase()) {
    case 'cash':
    case 'cash on delivery':
      return l.paymentMethodCash;
    default:
      // Un moyen de paiement ajouté côté base mais pas encore ici : mieux
      // vaut montrer sa clé que rien du tout.
      return raw;
  }
}
