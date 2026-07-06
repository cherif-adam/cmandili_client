import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../home/data/models/restaurant.dart';

class FavoritesNotifier extends StateNotifier<List<Restaurant>> {
  final _supabase = Supabase.instance.client;

  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _supabase
          .from('user_favorites')
          .select('restaurant_id, restaurants(*)')
          .eq('user_id', userId);

      state = (rows as List).map((row) {
        final r = row['restaurants'] as Map<String, dynamic>;
        return Restaurant(
          id: r['id'] as String,
          name: r['name'] as String? ?? '',
          description: r['description'] as String? ?? '',
          imageUrl: r['image_url'] as String? ?? '',
          rating: (r['rating'] as num?)?.toDouble() ?? 0,
          reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
          deliveryTime: (r['delivery_time_min'] as num?)?.toInt() ?? 30,
          deliveryFee: (r['delivery_fee'] as num?)?.toDouble() ?? 0,
          minimumOrder: (r['min_order'] as num?)?.toDouble() ?? 0,
          categories: r['categories'] != null
              ? List<String>.from(r['categories'] as List)
              : [],
          isOpen: r['is_open'] as bool? ?? true,
          latitude: (r['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (r['longitude'] as num?)?.toDouble() ?? 0,
          openingTime: r['opening_time'] as String?,
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> toggleFavorite(Restaurant restaurant) async {
    final userId = _supabase.auth.currentUser?.id;
    final isFav = state.any((r) => r.id == restaurant.id);

    // Optimistic UI update
    if (isFav) {
      state = state.where((r) => r.id != restaurant.id).toList();
    } else {
      state = [...state, restaurant];
    }

    if (userId == null) return;
    try {
      if (isFav) {
        await _supabase
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('restaurant_id', restaurant.id);
      } else {
        await _supabase.from('user_favorites').insert({
          'user_id': userId,
          'restaurant_id': restaurant.id,
        });
      }
    } catch (_) {
      // Revert optimistic update on failure
      await _loadFavorites();
    }
  }

  bool isFavorite(String restaurantId) {
    return state.any((r) => r.id == restaurantId);
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Restaurant>>((ref) {
  return FavoritesNotifier();
});

final isFavoriteProvider = Provider.family<bool, String>((ref, restaurantId) {
  final favorites = ref.watch(favoritesProvider);
  return favorites.any((r) => r.id == restaurantId);
});
