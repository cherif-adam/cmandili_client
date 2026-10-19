import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/models/service_category.dart';
import '../../../../core/providers/nearby_provider.dart';
import '../../../happy_hour/providers/happy_hour_provider.dart';
import '../../../restaurant/providers/restaurant_provider.dart';

/// The home tab's logic: the restaurant filters (cuisine chip and search
/// text, its state), the pull-to-refresh and the empty-list wording.
/// Auto-disposed with the tab, like the State it replaces.
final homeTabControllerProvider =
    NotifierProvider.autoDispose<HomeTabController, HomeTabFilters>(
        HomeTabController.new);

/// [category] is a chip value ('All' = every cuisine); [searchQuery] is
/// already lower-cased.
typedef HomeTabFilters = ({String category, String searchQuery});

class HomeTabController extends AutoDisposeNotifier<HomeTabFilters> {
  // ── State ─────────────────────────────────────────────────────────────────

  static const all = 'All';

  // Chip labels are also the canonical values stored in restaurants.categories
  // (the admin dashboard writes these exact strings — keep byte-identical).
  static const cuisineCategories = [
    'All',
    'Pâtisseries',
    'Pizza',
    'Burgers',
    'Sushi',
    'Mexican',
    'Italian',
    'Fast Food',
  ];

  @override
  HomeTabFilters build() => (category: all, searchQuery: '');

  // ── User actions ──────────────────────────────────────────────────────────

  void selectCategory(String category) =>
      state = (category: category, searchQuery: state.searchQuery);

  void search(String value) =>
      state = (category: state.category, searchQuery: value.toLowerCase());

  void clearSearch() => state = (category: state.category, searchQuery: '');

  /// "Voir tout": back to every cuisine, no search.
  void clearFilters() => state = (category: all, searchQuery: '');

  /// Pull to refresh: the customer's position, the shops and the deals.
  Future<void> refresh() async {
    ref.read(customerPositionProvider.notifier).refresh();
    ref.invalidate(shopPositionsProvider);
    ref.invalidate(restaurantsProvider);
    ref.invalidate(happyHourRestaurantsProvider);
    ref.invalidate(happyHourSupermarketsProvider);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Category-appropriate wording for the "nothing here yet" state. A
  /// generic "no shops" reads as a bug; naming the category makes it clear
  /// the category is simply new.
  static String emptyLabelFor(AppLocalizations l10n, ServiceType service) {
    switch (service) {
      case ServiceType.bakery:
        return l10n.homeEmptyBakery;
      case ServiceType.flowers:
        return l10n.homeEmptyFlowers;
      case ServiceType.pets:
        return l10n.homeEmptyPets;
      case ServiceType.gifts:
        return l10n.homeEmptyGifts;
      case ServiceType.electronics:
        return l10n.homeEmptyElectronics;
      default:
        return l10n.homeEmptyShops;
    }
  }
}
