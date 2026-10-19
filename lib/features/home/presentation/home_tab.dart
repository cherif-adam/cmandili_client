import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/models/service_category.dart';
import '../../../core/providers/nearby_provider.dart';
import '../../../core/providers/service_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../courier/presentation/courier_screen.dart';
import '../../facture/presentation/facture_screen.dart';
import '../../happy_hour/presentation/widgets/happy_hour_home_banner.dart';
import '../../happy_hour/providers/happy_hour_provider.dart';
import '../../promos/presentation/widgets/promos_home_banner.dart';
import '../../restaurant/providers/restaurant_provider.dart';
import '../../supermarket/presentation/supermarket_list_screen.dart';
import '../../vendors/presentation/vendor_list_screen.dart';
import 'widgets/food_hero_banner.dart';
import 'widgets/home_categories_section.dart';
import 'widgets/home_header.dart';
import 'widgets/popular_restaurants_header.dart';
import 'widgets/restaurant_filter_chips.dart';
import 'widgets/restaurant_list_sliver.dart';

/// The first tab of the home screen, top to bottom:
///
///   HomeHeader              address, notifications, search
///   HappyHourHomeBanner
///   PromosHomeBanner
///   HomeCategoriesSection   Restaurants, Supermarché, Fleurs, Colis…
///   then what the chosen category shows:
///     Restaurants  → FoodHeroBanner, RestaurantFilterChips,
///                    PopularRestaurantsHeader, RestaurantListSliver
///     Supermarché  → SupermarketListScreen
///     other shops  → VendorListScreen
///     Colis        → CourierScreen
///     Facture      → FactureScreen
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Chip labels are also the canonical values stored in restaurants.categories
  // (the admin dashboard writes these exact strings — keep byte-identical).
  final List<String> _categories = [
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(customerPositionProvider.notifier).refresh();
    ref.invalidate(shopPositionsProvider);
    ref.invalidate(restaurantsProvider);
    ref.invalidate(happyHourRestaurantsProvider);
    ref.invalidate(happyHourSupermarketsProvider);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final restaurants = ref.watch(nearbyRestaurantsProvider);
    final selectedService = ref.watch(selectedServiceProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          HomeHeader(
            selectedService: selectedService,
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
            onSearchCleared: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),

          // Happy Hour: live badge, real deal count/best discount, countdown
          // and a row of the running deals.
          const SliverToBoxAdapter(child: HappyHourHomeBanner()),

          // Percentage promotions (supermarket, flowers, pets, gifts,
          // electronics) — a separate banner from Happy Hour.
          const SliverToBoxAdapter(child: PromosHomeBanner()),

          SliverToBoxAdapter(
            child: HomeCategoriesSection(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ),

          // ── Restaurants ────────────────────────────────────────────────
          if (selectedService == ServiceType.foodDelivery) ...[
            SliverToBoxAdapter(
              child: FoodHeroBanner(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
            SliverToBoxAdapter(
              child: RestaurantFilterChips(
                categories: _categories,
                selected: _selectedCategory,
                onSelected: (category) =>
                    setState(() => _selectedCategory = category),
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.012,
              ),
              sliver: SliverToBoxAdapter(
                child: PopularRestaurantsHeader(
                  onSeeAll: _clearFilters,
                  screenWidth: screenWidth,
                ),
              ),
            ),
            RestaurantListSliver(
              restaurants: restaurants,
              selectedCategory: _selectedCategory,
              searchQuery: _searchQuery,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ],

          // ── Supermarkets ───────────────────────────────────────────────
          if (selectedService == ServiceType.supermarket)
            SupermarketListScreen(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),

          // ── Every other shop category ──────────────────────────────────
          // Bakery, flowers, pets, gifts, electronics share one list screen.
          if (selectedService.isVendorCategory &&
              selectedService != ServiceType.foodDelivery &&
              selectedService != ServiceType.supermarket)
            VendorListScreen(
              category: selectedService.vendorCategory!,
              emptyLabel:
                  _emptyLabelFor(AppLocalizations.of(context)!, selectedService),
            ),

          // ── Colis ──────────────────────────────────────────────────────
          if (selectedService == ServiceType.courier)
            SliverToBoxAdapter(
              child: CourierScreen(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),

          // ── Facture ────────────────────────────────────────────────────
          if (selectedService == ServiceType.billPayments)
            SliverToBoxAdapter(
              child: FactureScreen(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
            ),
        ],
      ),
    );
  }

  /// Category-appropriate wording for the "nothing here yet" state. A
  /// generic "no shops" reads as a bug; naming the category makes it clear
  /// the category is simply new.
  static String _emptyLabelFor(AppLocalizations l10n, ServiceType service) {
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
