import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../data/models/cart_item.dart';
import '../providers/cart_provider.dart';

/// Ajoute une ligne au panier, en demandant d'abord si le panier appartient
/// déjà à une autre boutique.
///
/// Un panier appartient à UNE boutique. Ce n'est pas une préférence
/// d'affichage : le checkout lit la boutique dans `cartItems.first` et
/// attribue la commande entière à celle-là, et `cartDeliveryFeeProvider`
/// classe les frais de la même façon. Un panier mélangé facturerait donc les
/// articles de la seconde boutique à la première, avec des frais de livraison
/// calculés depuis le mauvais point de retrait — et le partenaire recevrait
/// une commande contenant des articles qu'il ne vend pas.
///
/// L'écran des offres rend ce cas très facile à atteindre : trois onglets,
/// trois boutiques, un bouton par carte. D'où ce garde-fou, à appeler à la
/// place d'un `addItem` direct.
///
/// Renvoie `true` quand l'article a bien atterri dans le panier.
Future<bool> addToCartGuarded(
  BuildContext context,
  WidgetRef ref,
  CartItem item,
) async {
  final cart = ref.read(cartProvider);
  final currentShopId = cart.isEmpty ? null : cart.first.shopId;

  if (currentShopId != null && currentShopId != item.shopId) {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.cartFromAnotherShopTitle),
        content: Text(l.cartFromAnotherShopMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.emptyAndAdd),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    ref.read(cartProvider.notifier).clearCart();
  }

  ref.read(cartProvider.notifier).addItem(item);
  return true;
}
