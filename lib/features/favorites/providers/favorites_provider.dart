import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/data/models/restaurant.dart';
import '../data/favorites_repository.dart';

class FavoritesNotifier extends StateNotifier<List<Restaurant>> {
  final _repository = FavoritesRepository();

  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;
    try {
      state = await _repository.getFavorites(userId);
    } catch (_) {}
  }

  Future<void> toggleFavorite(Restaurant restaurant) async {
    final userId = _repository.currentUserId;
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
        await _repository.remove(userId, restaurant.id);
      } else {
        await _repository.add(userId, restaurant.id);
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
