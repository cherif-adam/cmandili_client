import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../data/models/order.dart';
import '../../providers/order_provider.dart';

/// "↻ Commander à nouveau" under a delivered food order.
///
/// Puts the order's items back in the cart (asking first if the cart is
/// not empty), skips the ones no longer available, then opens the cart.
class ReorderButton extends ConsumerWidget {
  final Order order;
  final double sw;
  final double sh;

  const ReorderButton({
    super.key,
    required this.order,
    required this.sw,
    required this.sh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _reorder(context, ref),
        icon: Icon(Icons.replay, size: sw * 0.042, color: AppColors.primary),
        label: Text(
          'Commander à nouveau',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: sw * 0.033,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          padding: EdgeInsets.symmetric(vertical: sh * 0.011),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sw * 0.03),
          ),
        ),
      ),
    );
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    final currentCart = ref.read(cartProvider);
    if (currentCart.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remplacer le panier ?'),
          content: const Text(
            'Votre panier actuel contient déjà des articles. Le remplacer par ceux de cette commande ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final repository = ref.read(orderRepositoryProvider);
      final result = await repository.getReorderItems(order.id);

      if (context.mounted) Navigator.pop(context);

      if (result.items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun article de cette commande n\'est disponible actuellement.'),
            ),
          );
        }
        return;
      }

      final cartNotifier = ref.read(cartProvider.notifier);
      cartNotifier.clearCart();
      for (final item in result.items) {
        cartNotifier.addItem(item);
      }

      if (!context.mounted) return;
      if (result.skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.skippedCount} article(s) non disponible(s) ont été ignoré(s).',
            ),
          ),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la recommande. Réessayez.')),
        );
      }
    }
  }
}
