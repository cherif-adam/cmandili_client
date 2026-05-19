import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supermarket_repository.dart';
import '../data/models/supermarket.dart';
import '../data/models/grocery_item.dart';
import '../../menu/data/models/item_variant.dart';

// Repository provider
final supermarketRepositoryProvider = Provider((ref) => SupermarketRepository());

// Fetch all supermarkets from Supabase
final supermarketsProvider = FutureProvider<List<Supermarket>>((ref) async {
  final repository = ref.watch(supermarketRepositoryProvider);
  return repository.getSupermarkets();
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
