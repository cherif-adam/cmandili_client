import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/data/models/restaurant.dart';

/// The customer's favourite restaurants (table `user_favorites`). Every
/// method lets errors propagate: [FavoritesNotifier] decides what a failure
/// means.
class FavoritesRepository {
  final _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<List<Restaurant>> getFavorites(String userId) async {
    final rows = await _supabase
        .from('user_favorites')
        // See order_repository: user_favorites.restaurant_id also still FKs
        // to restaurants_legacy, so embed through it and alias back.
        .select('restaurant_id, restaurants:restaurants_legacy(*)')
        .eq('user_id', userId);

    return (rows as List).map((row) {
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
  }

  Future<void> remove(String userId, String restaurantId) async {
    await _supabase
        .from('user_favorites')
        .delete()
        .eq('user_id', userId)
        .eq('restaurant_id', restaurantId);
  }

  Future<void> add(String userId, String restaurantId) async {
    await _supabase.from('user_favorites').insert({
      'user_id': userId,
      'restaurant_id': restaurantId,
    });
  }
}
