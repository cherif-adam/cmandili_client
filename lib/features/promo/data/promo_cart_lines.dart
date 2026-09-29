import '../../cart/data/models/cart_item.dart';

/// Les lignes du panier telles que `apply_promo_code` les attend.
///
/// DES IDENTIFIANTS ET DES QUANTITÉS, JAMAIS UN PRIX. C'est tout l'objet du
/// changement : l'application envoyait un sous-total que le serveur utilisait
/// tel quel, et un client modifié pouvait annoncer 4000 pour repartir avec
/// 400 de remise sur un panier à 40. Le serveur relit maintenant chaque prix
/// dans `vendor_items` ; il n'a plus besoin qu'on lui dise combien ça coûte,
/// seulement ce qu'il y a dans le panier.
///
/// La variante et les suppléments suivent, parce qu'ils changent le prix de
/// la ligne — une variante REMPLACE le prix de base, les suppléments s'y
/// ajoutent — et que le serveur doit arriver au même total que l'écran.
List<Map<String, dynamic>> promoCartLines(List<CartItem> items) {
  return [
    for (final item in items)
      {
        // Tous les identifiants d'article de l'application sont des
        // identifiants `vendor_items`, quelle que soit la catégorie.
        'item_id': item.id,
        'quantity': item.quantity,
        'variant_id': item.variant?.id,
        'option_ids': [
          for (final group in item.selectedOptionGroups)
            for (final selection in group.selections) selection.optionId,
        ],
      },
  ];
}
