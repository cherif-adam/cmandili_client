import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/vendor.dart';
import '../../../core/providers/vendor_provider.dart';
import 'happy_hour_provider.dart';

/// Les catégories dont les boutiques font du Happy Hour, dans l'ordre
/// d'affichage. Ce sont les onglets de l'écran HAPPY HOUR.
///
/// La liste vient de `vendor_categories.discount_mode`, jamais d'un `switch`
/// écrit ici. Basculer les fleuristes en Happy Hour est donc un UPDATE : leur
/// onglet quitte l'écran PROMOS et apparaît sur l'autre, sans nouvelle version
/// de l'application. C'est la même règle que celle que lit l'app partenaire
/// pour choisir entre le bouton « Happy Hour » et le bouton « Promo » — une
/// seule source, trois applications.
final happyHourCategoriesProvider = Provider<List<VendorCategory>>((ref) {
  return _categoriesWithMode(ref, happyHour: true);
});

/// Les catégories dont les boutiques font de la promotion en pourcentage :
/// les onglets de l'écran PROMOS.
final percentCategoriesProvider = Provider<List<VendorCategory>>((ref) {
  return _categoriesWithMode(ref, happyHour: false);
});

/// Le filtre `is_active` porte sur l'ONGLET, pas sur le mode.
///
/// Une catégorie masquée de l'accueil n'a pas d'onglet — le client ne peut de
/// toute façon pas la parcourir. Mais le mode de remise se lit sur la ligne
/// quel que soit `is_active` : c'est une règle de commerce, pas un réglage
/// d'affichage, et les confondre ferait disparaître le mode d'une catégorie
/// simplement cachée.
List<VendorCategory> _categoriesWithMode(Ref ref, {required bool happyHour}) {
  final all = ref.watch(vendorCategoriesProvider).valueOrNull ??
      VendorCategory.fallback;
  final matching =
      all.where((c) => c.usesHappyHour == happyHour).toList(growable: false);
  return [...matching]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// Le mode d'une catégorie donnée, pour trancher où va un article isolé
/// (une offre de la bannière d'accueil, par exemple).
///
/// Replie sur `'percent'` quand la catégorie est inconnue de cette version de
/// l'application : mieux vaut montrer l'article sur l'écran des promotions que
/// nulle part.
String discountModeOf(Ref ref, String? categoryId) {
  if (categoryId == null) return 'percent';
  final all = ref.watch(vendorCategoriesProvider).valueOrNull ??
      VendorCategory.fallback;
  for (final c in all) {
    if (c.id == categoryId) return c.discountMode;
  }
  return 'percent';
}

/// Les offres en cours à montrer sur la bannière HAPPY HOUR de l'accueil.
///
/// Filtrées sur le mode : une offre de supermarché qui apparaîtrait ici
/// ouvrirait un écran où son onglet n'existe plus. C'est la conséquence
/// directe de la séparation des deux écrans — la bannière ne peut plus
/// montrer « toutes les offres ».
final happyHourBannerDealsProvider = Provider<List<HappyHourDeal>>((ref) {
  return _dealsWithMode(ref, happyHour: true);
});

/// Les offres en cours à montrer sur la bannière PROMOS de l'accueil.
final promosBannerDealsProvider = Provider<List<HappyHourDeal>>((ref) {
  return _dealsWithMode(ref, happyHour: false);
});

List<HappyHourDeal> _dealsWithMode(Ref ref, {required bool happyHour}) {
  final wanted = happyHour ? 'happy_hour' : 'percent';
  final deals = ref.watch(happyHourLiveDealsProvider);
  return deals
      .where((d) => discountModeOf(ref, d.categoryId) == wanted)
      .toList(growable: false);
}

