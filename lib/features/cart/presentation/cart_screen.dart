import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/cart_provider.dart';
import '../../checkout/presentation/checkout_screen.dart';
import '../data/models/order_customization.dart';
import 'widgets/order_customization_widget.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final deliveryFee = ref.watch(cartDeliveryFeeProvider);
    final total = subtotal + deliveryFee;

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
          if (cartItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _showClearCartDialog(context, ref, screenWidth, screenHeight);
              },
              icon: Icon(Icons.delete_outline, size: screenWidth * 0.05),
              label: Text(
                AppLocalizations.of(context)!.clear,
                style: TextStyle(fontSize: screenWidth * 0.038),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? _EmptyCart(screenWidth: screenWidth, screenHeight: screenHeight)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = cartItems[index];
                      return _CartItemCard(
                        cartItem: cartItem,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        onRemove: () {
                          ref
                              .read(cartProvider.notifier)
                              .removeItem(cartItem.cartLineKey);
                        },
                        onQuantityChanged: (quantity) {
                          ref
                              .read(cartProvider.notifier)
                              .updateQuantity(cartItem.cartLineKey, quantity);
                        },
                      );
                    },
                  ),
                ),
                
                // Summary Card
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.06),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(screenWidth * 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: screenWidth * 0.05,
                        offset: Offset(0, -screenHeight * 0.006),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SummaryRow(
                          label: AppLocalizations.of(context)!.subtotal,
                          value: CurrencyFormatter.formatPrice(subtotal),
                          screenWidth: screenWidth,
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        _SummaryRow(
                          label: AppLocalizations.of(context)!.deliveryFee,
                          value: CurrencyFormatter.formatPrice(deliveryFee),
                          screenWidth: screenWidth,
                        ),
                        SizedBox(height: screenHeight * 0.025),
                        // Checkout Button BEFORE total
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    subtotal: subtotal,
                                    deliveryFee: deliveryFee,
                                    total: total,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(screenWidth * 0.04),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.proceedToCheckout,
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                          child: const Divider(),
                        ),
                        _SummaryRow(
                          label: AppLocalizations.of(context)!.total,
                          value: CurrencyFormatter.formatPrice(total),
                          isBold: true,
                          valueColor: AppColors.primary,
                          screenWidth: screenWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref, double screenWidth, double screenHeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          AppLocalizations.of(context)!.clearCart,
          style: TextStyle(fontSize: screenWidth * 0.048),
        ),
        content: Text(
          AppLocalizations.of(context)!.clearCartConfirmation,
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(
              AppLocalizations.of(context)!.clear,
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const _EmptyCart({
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.08),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: screenWidth * 0.2,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            AppLocalizations.of(context)!.cartEmpty,
            style: TextStyle(
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            AppLocalizations.of(context)!.addItemsToGetStarted,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: screenWidth * 0.04,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.02,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenWidth * 0.04),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)!.browseRestaurants,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  final dynamic cartItem;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;
  final double screenWidth;
  final double screenHeight;

  const _CartItemCard({
    required this.cartItem,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void showCustomizationDialog() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => OrderCustomizationWidget(
          initialCustomization: cartItem.customization,
          onSave: (customization) {
            // Update cart item with customization
            cartItem.customization = customization;
          },
        ),
      );
    }
    return Dismissible(
      key: Key(cartItem.cartLineKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: screenWidth * 0.05),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.error,
          size: screenWidth * 0.08,
        ),
      ),
      onDismissed: (direction) => onRemove(),
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.02),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: screenWidth * 0.025,
              offset: Offset(0, screenHeight * 0.006),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.03),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(screenWidth * 0.04),
                child: (cartItem.imageUrl.isNotEmpty && cartItem.imageUrl.startsWith('http'))
                    ? CachedNetworkImage(
                        imageUrl: cartItem.imageUrl,
                        width: screenWidth * 0.22,
                        height: screenWidth * 0.22,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.background,
                          child: const Icon(Icons.shopping_basket, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: screenWidth * 0.22,
                        height: screenWidth * 0.22,
                        color: AppColors.background,
                        child: const Icon(Icons.shopping_basket, color: Colors.grey),
                      ),
              ),
              
              SizedBox(width: screenWidth * 0.04),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartItem.name,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cartItem.optionsSummary != null) ...[
                      SizedBox(height: screenHeight * 0.004),
                      Text(
                        cartItem.optionsSummary!,
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      CurrencyFormatter.formatPrice(cartItem.price),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.038,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    
                    // Quantity Controls
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (cartItem.quantity > 1) {
                                    onQuantityChanged(cartItem.quantity - 1);
                                  }
                                },
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                child: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  child: Icon(
                                    Icons.remove,
                                    size: screenWidth * 0.045,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              Container(
                                width: screenWidth * 0.08,
                                alignment: Alignment.center,
                                child: Text(
                                  '${cartItem.quantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: screenWidth * 0.04,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  onQuantityChanged(cartItem.quantity + 1);
                                },
                                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                                child: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  child: Icon(
                                    Icons.add,
                                    size: screenWidth * 0.045,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.formatPrice(cartItem.totalPrice),
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    
                    // Special Instructions Button
                    SizedBox(height: screenHeight * 0.015),
                    InkWell(
                      onTap: showCustomizationDialog,
                      borderRadius: BorderRadius.circular(screenWidth * 0.03),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: cartItem.customization != null
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(screenWidth * 0.03),
                          border: Border.all(
                            color: cartItem.customization != null
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cartItem.customization != null
                                  ? (cartItem.customization!.type == CustomizationType.voice
                                      ? Icons.mic
                                      : Icons.edit_note)
                                  : Icons.add_circle_outline,
                              size: screenWidth * 0.04,
                              color: cartItem.customization != null
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            ),
                            SizedBox(width: screenWidth * 0.015),
                            Flexible(
                              child: Text(
                                cartItem.customization != null
                                    ? AppLocalizations.of(context)!.customization
                                    : AppLocalizations.of(context)!.addSpecialInstructions,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
                                  color: cartItem.customization != null
                                      ? AppColors.primary
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double screenWidth;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.screenWidth,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? screenWidth * 0.045 : screenWidth * 0.04,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Theme.of(context).textTheme.bodyLarge?.color : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? screenWidth * 0.05 : screenWidth * 0.04,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (isBold ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).textTheme.bodyLarge?.color),
          ),
        ),
      ],
    );
  }
}
