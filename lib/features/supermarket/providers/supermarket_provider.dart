import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supermarket_repository.dart';
import '../data/models/supermarket.dart';
import '../data/models/grocery_item.dart';
import '../../menu/data/models/item_variant.dart';

// Repository provider
final supermarketRepositoryProvider = Provider((ref) => SupermarketRepository());

// Live list of supermarkets — updates automatically when a partner adds,
// edits, or removes one, no manual refresh needed.
final supermarketsProvider = StreamProvider<List<Supermarket>>((ref) {
  final repository = ref.watch(supermarketRepositoryProvider);
  return repository.watchSupermarkets();
});

// Fetch grocery items for a specific supermarket from Supabase
final groceryItemsProvider = FutureProvider.family<List<GroceryItem>, String>((ref, supermarketId) async {
  final repository = ref.watch(supermarketRepositoryProvider);
  return repository.getGroceryItems(supermarketId);
});

// Variants for a single grocery item.
final groceryItemVariantsProvider =
    FutureProvider.family<List<ItemVariant>, String>((ref, groceryItemId) async {
  final repository = ref.watch(supermarketRepositoryProvider);
  return repository.getGroceryItemVariants(groceryItemId);
});
