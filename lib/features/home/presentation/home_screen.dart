import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/service_category.dart';
import '../../../core/providers/service_provider.dart';
import '../../../core/providers/location_provider.dart';
// import '../data/models/restaurant.dart'; // Removed unused import
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/saved_addresses_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../restaurant/presentation/widgets/restaurant_card.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../supermarket/presentation/supermarket_list_screen.dart';
import 'widgets/service_selector.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../happy_hour/presentation/happy_hour_screen.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../orders/presentation/order_tracking_screen.dart';
import '../../orders/providers/order_provider.dart';
import '../../orders/data/models/order.dart';
import '../../ai_search/presentation/ai_search_screen.dart';
import '../../../screens/ai_chat_screen.dart';
import '../../courier/presentation/courier_screen.dart';
import '../../facture/presentation/facture_screen.dart';

import '../../restaurant/providers/restaurant_provider.dart';

// Inline provider removed. Now using provider from restaurant/providers/restaurant_provider.dart


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _selectedIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final cartItemCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: screenHeight * 0.1),
        child: FloatingActionButton(
          heroTag: 'ai_chat_fab',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiChatScreen()),  // ← no const
          ),
          backgroundColor: const Color(0xFF6C3DE1),
          tooltip: 'AI Chat',
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Main Content Area
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeContent(screenHeight, screenWidth),
              const FavoritesScreen(),
              const OrderHistoryScreen(),
              const CartScreen(),
              const ProfileScreen(),
            ],
          ),

          // Floating Bottom Navigation Bar
          Positioned(
            bottom: screenHeight * 0.03,
            left: screenWidth * 0.06,
            right: screenWidth * 0.06,
            child: Container(
              height: screenHeight * 0.085,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(screenWidth * 0.06),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: screenWidth * 0.05,
                    offset: Offset(0, screenHeight * 0.012),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, screenWidth, screenHeight),
                  _buildNavItem(1, Icons.favorite_rounded, Icons.favorite_border_rounded, screenWidth, screenHeight),
                  _buildNavItem(2, Icons.receipt_long_rounded, Icons.receipt_long_outlined, screenWidth, screenHeight),
                  _buildCartNavItem(3, cartItemCount, screenWidth, screenHeight),
                  _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, screenWidth, screenHeight),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(double screenHeight, double screenWidth) {
    final restaurants = ref.watch(restaurantsProvider);
    final selectedService = ref.watch(selectedServiceProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(restaurantsProvider);
      },
      color: AppColors.primary,
      child: CustomScrollView(
      slivers: [
        // Custom App Bar
        SliverAppBar(
          expandedHeight: screenHeight * 0.18,
          floating: true,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Flexible: lets the address column shrink when
                          // the notification bell needs space → no overflow
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SavedAddressesScreen(),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.deliverTo,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: screenWidth * 0.035,
                                    ),
                                  ),
                                  SizedBox(height: screenHeight * 0.005),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: screenWidth * 0.05,
                                      ),
                                      SizedBox(width: screenWidth * 0.01),
                                      // Flexible: long address won't overflow
                                      Flexible(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final loc = ref.watch(locationProvider);
                                            return Text(
                                              loc == 'Current Location'
                                                  ? AppLocalizations.of(context)!.currentLocation
                                                  : loc,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: screenWidth * 0.04,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.01),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        size: screenWidth * 0.05,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(screenWidth * 0.03),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: screenWidth * 0.06,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const NotificationScreen(),
                                      ),
                                    );
                                  },
                                ),
                                if (ref.watch(unreadNotificationCountProvider) > 0)
                                  Positioned(
                                    top: screenHeight * 0.008,
                                    right: screenWidth * 0.02,
                                    child: Container(
                                      padding: EdgeInsets.all(screenWidth * 0.01),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: BoxConstraints(
                                        minWidth: screenWidth * 0.045,
                                        minHeight: screenWidth * 0.045,
                                      ),
                                      child: Text(
                                        '${ref.watch(unreadNotificationCountProvider)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: screenWidth * 0.025,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(screenHeight * 0.1),
            child: Container(
              height: screenHeight * 0.1,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.012,
              ),
              alignment: Alignment.topCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(screenWidth * 0.04),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: screenWidth * 0.025,
                      offset: Offset(0, screenHeight * 0.006),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: screenWidth * 0.038,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchRestaurants,
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: screenWidth * 0.038,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: screenWidth * 0.06,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: screenWidth * 0.05),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : Tooltip(
                            message: 'AI Search',
                            child: IconButton(
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF6C3DE1),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AiSearchScreen(),
                                ),
                              ),
                            ),
                          ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                      vertical: screenHeight * 0.017,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Active Order Banner
        _buildActiveOrderBanner(screenWidth, screenHeight),

        // Happy Hour Banner
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.015,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HappyHourScreen()),
                );
              },
              child: Container(
                height: screenHeight * 0.16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/happy_hour_banner.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.2),
                          errorBuilder: (context, error, stackTrace) =>
                              const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFCC00), Color(0xFFFF9500)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.happyHourOverlayGradient,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(
                          Icons.local_offer,
                          size: 150,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      AppLocalizations.of(context)!.happyHour,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.052,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Text(
                                      AppLocalizations.of(context)!.saveUpTo60,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenWidth * 0.033,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.viewDeals,
                                style: const TextStyle(
                                  color: Color(0xFFFF9500),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Service Selector (Food, Supermarket, Bills)
        SliverToBoxAdapter(
          child: ServiceSelector(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        ),

        // Content based on selected service
        if (selectedService == ServiceType.foodDelivery) ...[
          // Food hero banner
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.01,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/amana_food_hero.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.15),
                        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: AppColors.orangeBannerGradient),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(context)!.foodHeroTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.05,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Categories
          SliverToBoxAdapter(
            child: Container(
              height: screenHeight * 0.075,
              margin: EdgeInsets.only(
                top: screenHeight * 0.012,
                bottom: screenHeight * 0.012,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: screenWidth * 0.03),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        backgroundColor: Theme.of(context).cardColor,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                          fontSize: screenWidth * 0.036,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.01,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * 0.05),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : AppColors.textLight.withValues(alpha: 0.2),
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Popular Header
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.012,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.popularRestaurants,
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: Text(
                      AppLocalizations.of(context)!.seeAll,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: screenWidth * 0.038,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Restaurants List
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.05,
              0,
              screenWidth * 0.05,
              screenHeight * 0.12, // Bottom padding for floating nav
            ),
            sliver: restaurants.when(
              data: (restaurantList) {
                // Filter by category
                var filtered = restaurantList;
                if (_selectedCategory != 'All') {
                  filtered = filtered.where((r) =>
                    r.categories.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase())
                  ).toList();
                }
                // Filter by search query (name, description, or category —
                // so typing "pâtisseries" finds tagged venues too)
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((r) =>
                    r.name.toLowerCase().contains(_searchQuery) ||
                    r.description.toLowerCase().contains(_searchQuery) ||
                    r.categories.any((c) => c.toLowerCase().contains(_searchQuery))
                  ).toList();
                }

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(screenHeight * 0.05),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: screenWidth * 0.12, color: Colors.grey[400]),
                            SizedBox(height: screenHeight * 0.02),
                            Text(
                              AppLocalizations.of(context)!.noRestaurantsFound,
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final restaurant = filtered[index];
                      return RestaurantCard(restaurant: restaurant);
                    },
                    childCount: filtered.length,
                  ),
                );
              },
              loading: () => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenHeight * 0.05),
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(screenHeight * 0.05),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error loading restaurants: $error'),
                        SizedBox(height: screenHeight * 0.02),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(restaurantsProvider),
                          icon: const Icon(Icons.refresh),
                          label: Text(AppLocalizations.of(context)!.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        
        // Supermarket List
        if (selectedService == ServiceType.supermarket)
          SupermarketListScreen(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),

        // Courier / Colis
        if (selectedService == ServiceType.courier)
          SliverToBoxAdapter(
            child: CourierScreen(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ),

        // Facture / Bill payment
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

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    double screenWidth,
    double screenHeight,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(screenWidth * 0.03),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
        ),
        child: Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: screenWidth * 0.07,
        ),
      ),
    );
  }

  Widget _buildActiveOrderBanner(double sw, double sh) {
    final activeOrdersAsync = ref.watch(userOrdersProvider);
    return activeOrdersAsync.maybeWhen(
      data: (orders) {
        final activeOrder = orders.where((o) => 
          o.status != OrderStatus.delivered && 
          o.status != OrderStatus.cancelled
        ).firstOrNull;

        if (activeOrder == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.05, vertical: sh * 0.01),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(orderId: activeOrder.id),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(sw * 0.04),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(sw * 0.04),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(sw * 0.02),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining, color: Colors.white),
                    ),
                    SizedBox(width: sw * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.activeOrder,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: sw * 0.04,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            activeOrder.getStatusText(),
                            style: TextStyle(fontSize: sw * 0.035),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildCartNavItem(int index, int count, double screenWidth, double screenHeight) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
            ),
            child: Icon(
              isSelected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: screenWidth * 0.07,
            ),
          ),
          if (count > 0)
            Positioned(
              top: screenHeight * 0.01,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.01),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: screenWidth * 0.04,
                  minHeight: screenWidth * 0.04,
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}