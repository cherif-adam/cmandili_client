import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../cart/presentation/cart/cart_screen.dart';

/// The green "🛒(3) Voir le panier" floating button on a supermarket's
/// page. The page only shows it once the cart has something.
class SupermarketCartButton extends StatelessWidget {
  final int cartItemCount;

  const SupermarketCartButton({super.key, required this.cartItemCount});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );
      },
      backgroundColor: const Color(0xFF4CAF50),
      icon: badges.Badge(
        badgeContent: Text(
          '$cartItemCount',
          style: const TextStyle(color: Colors.white),
        ),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
      label: Text(
        AppLocalizations.of(context)!.viewCart,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
