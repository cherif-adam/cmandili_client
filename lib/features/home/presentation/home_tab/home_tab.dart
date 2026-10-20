import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/models/service_category.dart';
import '../../../../core/providers/service_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../courier/presentation/courier/courier_screen.dart';
import '../../../facture/presentation/facture/facture_screen.dart';
import '../../../happy_hour/presentation/widgets/happy_hour_home_banner.dart';
import '../../../promos/presentation/widgets/promos_home_banner.dart';
import '../../../supermarket/presentation/supermarket_list/supermarket_list_screen.dart';
import '../../../vendors/presentation/vendor_list/vendor_list_screen.dart';
import '../../../restaurant/providers/restaurant_provider.dart';
import '../../data/models/restaurant.dart';
import 'home_tab_controller.dart';
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
///
/// UI only: the restaurant filters, the refresh and the empty-list wording
/// live in [HomeTabController]; the search field's text controller stays
/// here.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final restaurants = ref.watch(nearbyRestaurantsProvider);
    final selectedService = ref.watch(selectedServiceProvider);
    final filters = ref.watch(homeTabControllerProvider);
    final controller = ref.read(homeTabControllerProvider.notifier);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          HomeHeader(
            selectedService: selectedService,
            searchController: _searchController,
            searchQuery: filters.searchQuery,
            onSearchChanged: controller.search,
            onSearchCleared: () {
              _searchController.clear();
              controller.clearSearch();
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
          if (selectedService == ServiceType.foodDelivery)
            _RestaurantsSection(
              restaurants: restaurants,
              filters: filters,
              onCategorySelected: controller.selectCategory,
              onSeeAll: () {
                controller.clearFilters();
                _searchController.clear();
              },
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),

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
              emptyLabel: HomeTabController.emptyLabelFor(
                  AppLocalizations.of(context)!, selectedService),
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
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// What "Restaurants" shows: the hero banner, the cuisine chips, the
/// "popular" header and the filtered restaurant list.
class _RestaurantsSection extends StatelessWidget {
  const _RestaurantsSection({
    required this.restaurants,
    required this.filters,
    required this.onCategorySelected,
    required this.onSeeAll,
    required this.screenWidth,
    required this.screenHeight,
  });

  final AsyncValue<List<Restaurant>> restaurants;
  final HomeTabFilters filters;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSeeAll;
  final double screenWidth;
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: FoodHeroBanner(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        ),
        SliverToBoxAdapter(
          child: RestaurantFilterChips(
            categories: HomeTabController.cuisineCategories,
            selected: filters.category,
            onSelected: onCategorySelected,
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
              onSeeAll: onSeeAll,
              screenWidth: screenWidth,
            ),
          ),
        ),
        RestaurantListSliver(
          restaurants: restaurants,
          selectedCategory: filters.category,
          searchQuery: filters.searchQuery,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        ),
      ],
    );
  }
}
