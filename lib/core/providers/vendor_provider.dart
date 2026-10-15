import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vendor_repository.dart';
import '../models/vendor.dart';
import 'nearby_provider.dart';

final vendorRepositoryProvider =
    Provider<VendorRepository>((ref) => VendorRepository());

/// Category catalogue, loaded once from the database so a new category can be
/// launched without an app release. Falls back to the built-in list inside
/// the repository when the table is unreachable.
final vendorCategoriesProvider = FutureProvider<List<VendorCategory>>((ref) {
  return ref.watch(vendorRepositoryProvider).getCategories();
});

/// Live list of shops in one category, keyed by the `vendors.category` value.
final vendorsByCategoryProvider =
    StreamProvider.family<List<Vendor>, String>((ref, category) {
  return ref.watch(vendorRepositoryProvider).watchVendors(category);
});

/// The shops of one category within [kShopRadiusKm] of the customer.
/// Refresh through [vendorsByCategoryProvider].
final nearbyVendorsByCategoryProvider =
    Provider.family<AsyncValue<List<Vendor>>, String>((ref, category) {
  return keepNearby(
    ref.watch(customerPositionProvider),
    ref.watch(vendorsByCategoryProvider(category)),
    (v) => (lat: v.latitude, lng: v.longitude),
  );
});

/// Items belonging to one shop.
final vendorItemsProvider =
    FutureProvider.family<List<VendorItem>, String>((ref, vendorId) {
  return ref.watch(vendorRepositoryProvider).getItems(vendorId);
});

/// La catégorie de commerce passe-t-elle par une étape de préparation ?
///
/// `null` quand la catégorie est inconnue — l'appelant décide alors du repli.
/// La valeur vient de `vendor_categories.has_preparation_step`, donc du même
/// endroit pour les trois applications : elles ne peuvent pas se contredire,
/// et ouvrir une catégorie qui prépare ses commandes ne demandera pas une
/// nouvelle version de chacune.
final hasPreparationStepProvider = Provider.family<bool?, String?>((ref, categoryId) {
  if (categoryId == null || categoryId.isEmpty) return null;
  final all = ref.watch(vendorCategoriesProvider).valueOrNull ??
      VendorCategory.fallback;
  for (final c in all) {
    if (c.id == categoryId) return c.hasPreparationStep;
  }
  return null;
});
