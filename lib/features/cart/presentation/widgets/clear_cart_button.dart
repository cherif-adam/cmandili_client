import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';

/// The red "🗑 Vider" button in the cart's app bar. Asks for confirmation,
/// then empties the cart.
class ClearCartButton extends ConsumerWidget {
  final double screenWidth;

  const ClearCartButton({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => _showClearCartDialog(context, ref),
      icon: Icon(Icons.delete_outline, size: screenWidth * 0.05),
      label: Text(
        AppLocalizations.of(context)!.clear,
        style: TextStyle(fontSize: screenWidth * 0.038),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
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
