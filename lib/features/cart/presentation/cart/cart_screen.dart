import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../data/models/cart_item.dart';
import '../../providers/cart_provider.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/cart_summary_panel.dart';
import 'widgets/clear_cart_button.dart';
import 'widgets/empty_cart_view.dart';

/// The cart: one card per line, then the summary with the checkout button.
///
///   AppBar: "Mon panier" ............ ClearCartButton
///   empty → EmptyCartView
///   else  → Column
///             ├─ _CartItemsList (one CartItemCard per line)
///             └─ CartSummaryPanel (subtotal, delivery, total, checkout)
///
/// UI only: the lines and their totals come from [cartProvider] and its
/// derived providers, which are this screen's controller.
class CartScreen extends ConsumerWidget {
  /// Space kept free at the bottom for whatever floats over this screen.
  /// As the home screen's cart tab, the menu bar (and the active-order pill)
  /// sit on top of it; without this they covered the total and most of the
  /// checkout button.
  final double bottomInset;

  const CartScreen({super.key, this.bottomInset = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.myCart,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
        actions: [
          if (cartItems.isNotEmpty) ClearCartButton(screenWidth: screenWidth),
        ],
      ),
      body: cartItems.isEmpty
          ? EmptyCartView(screenWidth: screenWidth, screenHeight: screenHeight)
          : Column(
              children: [
                Expanded(
                  child: _CartItemsList(
                    cartItems: cartItems,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    onRemove: (key) =>
                        ref.read(cartProvider.notifier).removeItem(key),
                    onQuantityChanged: (key, quantity) => ref
                        .read(cartProvider.notifier)
                        .updateQuantity(key, quantity),
                  ),
                ),
                CartSummaryPanel(
                  subtotal: subtotal,
                  deliveryFee: deliveryFee,
                  bottomInset: bottomInset,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
              ],
            ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One CartItemCard per cart line. [onRemove] and [onQuantityChanged]
/// receive the line's cartLineKey.
class _CartItemsList extends StatelessWidget {
  const _CartItemsList({
    required this.cartItems,
    required this.screenWidth,
    required this.screenHeight,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  final List<CartItem> cartItems;
  final double screenWidth;
  final double screenHeight;
  final ValueChanged<String> onRemove;
  final void Function(String key, int quantity) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(screenWidth * 0.05),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final cartItem = cartItems[index];
        return CartItemCard(
          cartItem: cartItem,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          onRemove: () => onRemove(cartItem.cartLineKey),
          onQuantityChanged: (quantity) =>
              onQuantityChanged(cartItem.cartLineKey, quantity),
        );
      },
    );
  }
}
