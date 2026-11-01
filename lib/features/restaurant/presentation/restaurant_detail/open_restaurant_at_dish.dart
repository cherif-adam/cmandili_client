import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/vendor_provider.dart';
import 'restaurant_detail_screen.dart';

/// Opens a restaurant's page from a search or chat result, which only knows
/// the restaurant's id, scrolled to [dishId] (the dish glows a moment).
///
/// The restaurant is read fresh rather than rebuilt from the result's few
/// fields: its page blocks the cart when it is closed and applies its
/// minimum order, so it needs the real row. Returns false, opening nothing,
/// when the restaurant is gone. Errors reaching the database propagate.
Future<bool> openRestaurantAtDish(
  BuildContext context,
  WidgetRef ref, {
  required String restaurantId,
  String? dishId,
}) async {
  final restaurant =
      await ref.read(shopRepositoryProvider).getRestaurant(restaurantId);
  if (restaurant == null || !context.mounted) return false;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RestaurantDetailScreen(
        restaurant: restaurant,
        highlightItemId: dishId,
      ),
    ),
  );
  return true;
}
