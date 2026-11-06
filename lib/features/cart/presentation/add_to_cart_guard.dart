import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // A cart may now hold several shops: checkout splits it into one order per
  // shop, each with its own delivery fee.
  ref.read(cartProvider.notifier).addItem(item);
  return true;
}
