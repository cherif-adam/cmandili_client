import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/order_customization.dart';
import 'order_customization_widget.dart';

/// One line of the cart. Swipe left to remove it.
///
///   Row
///   ├─ _CartItemImage
///   └─ Column
///       ├─ name, chosen options, unit price
///       ├─ Row: _QuantityStepper ........ line total
///       └─ _SpecialInstructionsButton
class CartItemCard extends ConsumerWidget {
  final CartItem cartItem;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;
  final double screenWidth;
  final double screenHeight;

  const CartItemCard({
    super.key,
    required this.cartItem,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

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
              _CartItemImage(imageUrl: cartItem.imageUrl, screenWidth: screenWidth),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartItem.name,
                      style: TextStyle(
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                        color: textColor,
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
                    Row(
                      children: [
                        _QuantityStepper(
                          quantity: cartItem.quantity,
                          onChanged: onQuantityChanged,
                          screenWidth: screenWidth,
                        ),
                        const Spacer(),
                        Text(
                          CurrencyFormatter.formatPrice(cartItem.totalPrice),
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    _SpecialInstructionsButton(
                      cartItem: cartItem,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
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

/// The product photo, or a basket icon when there is none.
class _CartItemImage extends StatelessWidget {
  final String imageUrl;
  final double screenWidth;

  const _CartItemImage({required this.imageUrl, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(screenWidth * 0.04),
      child: (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
          ? CachedNetworkImage(
              imageUrl: imageUrl,
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
    );
  }
}

/// "−  2  +" — never goes below 1 (swipe the card to remove it).
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final Function(int) onChanged;
  final double screenWidth;

  const _QuantityStepper({
    required this.quantity,
    required this.onChanged,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (quantity > 1) {
                onChanged(quantity - 1);
              }
            },
            borderRadius: BorderRadius.circular(screenWidth * 0.03),
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.02),
              child: Icon(
                Icons.remove,
                size: screenWidth * 0.045,
                color: textColor,
              ),
            ),
          ),
          Container(
            width: screenWidth * 0.08,
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: screenWidth * 0.04,
                color: textColor,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              onChanged(quantity + 1);
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
    );
  }
}

/// "⊕ Ajouter des instructions spéciales" — opens the note / voice sheet.
/// Turns green once the customer has added something.
class _SpecialInstructionsButton extends StatelessWidget {
  final CartItem cartItem;
  final double screenWidth;
  final double screenHeight;

  const _SpecialInstructionsButton({
    required this.cartItem,
    required this.screenWidth,
    required this.screenHeight,
  });

  void _showCustomizationDialog(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final hasNote = cartItem.customization != null;
    return InkWell(
      onTap: () => _showCustomizationDialog(context),
      borderRadius: BorderRadius.circular(screenWidth * 0.03),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.03,
          vertical: screenHeight * 0.01,
        ),
        decoration: BoxDecoration(
          color: hasNote
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(screenWidth * 0.03),
          border: Border.all(
            color: hasNote ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasNote
                  ? (cartItem.customization!.type == CustomizationType.voice
                      ? Icons.mic
                      : Icons.edit_note)
                  : Icons.add_circle_outline,
              size: screenWidth * 0.04,
              color: hasNote ? AppColors.primary : Colors.grey.shade600,
            ),
            SizedBox(width: screenWidth * 0.015),
            Flexible(
              child: Text(
                hasNote
                    ? AppLocalizations.of(context)!.customization
                    : AppLocalizations.of(context)!.addSpecialInstructions,
                style: TextStyle(
                  fontSize: screenWidth * 0.028,
                  color: hasNote ? AppColors.primary : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
