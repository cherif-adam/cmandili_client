import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/models/vendor.dart';
import '../../../../core/utils/platform_pricing.dart';
import '../../../cart/data/models/cart_item.dart';
import '../../../cart/presentation/add_to_cart_guard.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../providers/happy_hour_provider.dart';
import 'happy_hour_card.dart';

/// La liste d'offres d'UNE catégorie, la même pour les deux écrans.
///
/// L'écran HAPPY HOUR et l'écran PROMOS ne diffèrent que par les catégories
/// qu'ils affichent et par leur couleur : les cartes, l'ajout au panier, le
/// message et le chemin vers la commande sont identiques. Un seul widget, donc
/// — sans quoi les deux écrans divergeraient à la première correction.
class DealsTab extends ConsumerWidget {
  const DealsTab({
    super.key,
    required this.category,
    required this.accentColor,
  });

  final VendorCategory category;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le `switch` ci-dessous ne décide PAS sur quel écran l'article apparaît
    // — ça, c'est `discount_mode` — mais dans quelle TABLE il se lit et quel
    // type de ligne de panier il produit. Ce sont deux faits de schéma :
    // `food_items` et `grocery_items` sont des vues propres à ces deux
    // catégories, et `order_items` a une colonne de clé étrangère par
    // verticale. Lire un plat comme un VendorItem l'enregistrerait sous
    // `vendor_item_id`, et le partenaire ne le retrouverait pas.
    switch (category.id) {
      case 'food':
        return _list<dynamic>(
          context,
          ref,
          ref.watch(happyHourRestaurantsProvider),
          (item) => _Deal(
            name: item.name,
            description: item.description,
            imageUrl: item.imageUrl,
            originalPrice: applyPlatformMarkup(item.price),
            discountPrice: item.clientPrice,
            endsAt: item.discountEndTime,
            quantity: item.discountQuantity,
            cartItem: CartItem.restaurant(foodItem: item, quantity: 1),
          ),
        );
      case 'grocery':
        return _list<dynamic>(
          context,
          ref,
          ref.watch(happyHourSupermarketsProvider),
          (item) => _Deal(
            name: item.name,
            description: '${item.description} (${item.unit})',
            imageUrl: item.imageUrl,
            originalPrice: applyPlatformMarkup(item.price),
            discountPrice: item.clientPrice,
            endsAt: item.discountEndTime,
            quantity: item.discountQuantity,
            cartItem: CartItem.grocery(groceryItem: item, quantity: 1),
          ),
        );
      default:
        final async = ref.watch(happyHourShopsProvider).whenData(
              (items) => items
                  .where((i) => i.shopCategory == category.id)
                  .toList(growable: false),
            );
        return _list<dynamic>(
          context,
          ref,
          async,
          (item) => _Deal(
            name: item.name,
            description: item.description,
            imageUrl: item.imageUrl,
            originalPrice: applyPlatformMarkup(item.price),
            discountPrice: applyPlatformMarkup(item.effectivePrice),
            endsAt: item.discountEndTime,
            quantity: item.discountQuantity,
            cartItem: CartItem.vendor(vendorItem: item, quantity: 1),
          ),
        );
    }
  }

  Widget _list<T>(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<T>> async,
    _Deal Function(dynamic item) toDeal,
  ) {
    final l = AppLocalizations.of(context)!;
    return async.when(
      data: (items) {
        if (items.isEmpty) return Center(child: Text(l.noDealsRightNow));
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final deal = toDeal(items[index]);
            return HappyHourCard(
              imageUrl: deal.imageUrl,
              name: deal.name,
              description: deal.description,
              originalPrice: deal.originalPrice,
              discountPrice: deal.discountPrice,
              discountEndTime: deal.endsAt,
              discountQuantity: deal.quantity,
              accentColor: accentColor,
              onTap: () {},
              onGrab: () => _grab(context, ref, deal),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text(l.happyHourLoadError)),
    );
  }

  /// Ajoute l'offre au panier et ouvre la voie vers la suite.
  ///
  /// Sans l'action « Voir le panier », le client voyait passer un message et
  /// restait sur l'écran des offres : rien ne menait à la commande. Le message
  /// dure assez longtemps pour être touché — 1,5 s ne suffisait pas.
  Future<void> _grab(BuildContext context, WidgetRef ref, _Deal deal) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final added = await addToCartGuarded(context, ref, deal.cartItem);
    if (!added) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.happyHourAddedToCart(deal.name)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l.viewCart,
            textColor: Colors.white,
            onPressed: () => navigator.push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ),
      );
  }
}

/// Ce qu'une carte a besoin de savoir, quelle que soit la table d'origine.
class _Deal {
  const _Deal({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.originalPrice,
    required this.discountPrice,
    required this.endsAt,
    required this.quantity,
    required this.cartItem,
  });

  final String name;
  final String description;
  final String imageUrl;
  final double originalPrice;
  final double discountPrice;
  final DateTime? endsAt;
  final int? quantity;
  final CartItem cartItem;
}
