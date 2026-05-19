import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../providers/happy_hour_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/data/models/cart_item.dart';
import 'widgets/happy_hour_card.dart';

class HappyHourScreen extends ConsumerStatefulWidget {
  const HappyHourScreen({super.key});

  @override
  ConsumerState<HappyHourScreen> createState() => _HappyHourScreenState();
}

class _HappyHourScreenState extends ConsumerState<HappyHourScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 4,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 60),
                centerTitle: false,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.happyHour,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.5), offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.saveUpTo60,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.5), offset: const Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=1350&q=80',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.orange.shade200),
                      errorWidget: (context, url, error) => Container(color: Colors.orange.shade200),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFFFCC00),
                    indicatorWeight: 3,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.restaurants),
                      Tab(text: AppLocalizations.of(context)!.supermarkets),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRestaurantList(),
            _buildSupermarketList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    final asyncValue = ref.watch(happyHourRestaurantsProvider);
    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.noDealsRightNow));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return HappyHourCard(
              imageUrl: item.imageUrl,
              name: item.name,
              description: item.description,
              originalPrice: item.price,
              discountPrice: item.discountPrice!,
              discountEndTime: item.discountEndTime!,
              discountQuantity: item.discountQuantity,
              onTap: () {
                // Navigate to details or add to cart
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Selected ${item.name}")),
                );
              },
              onGrab: () {
                final cartItem = CartItem.restaurant(
                  foodItem: item,
                  quantity: 1,
                );
                ref.read(cartProvider.notifier).addItem(cartItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${item.name} added to cart!"),
                    backgroundColor: Colors.green,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildSupermarketList() {
    final asyncValue = ref.watch(happyHourSupermarketsProvider);
    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context)!.noDealsRightNow));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return HappyHourCard(
              imageUrl: item.imageUrl,
              name: item.name,
              description: "${item.description} (${item.unit})",
              originalPrice: item.price,
              discountPrice: item.discountPrice!,
              discountEndTime: item.discountEndTime!,
              discountQuantity: item.discountQuantity,
              onTap: () {
                 // Navigate to details or add to cart
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Selected ${item.name}")),
                );
              },
              onGrab: () {
                final cartItem = CartItem.grocery(
                  groceryItem: item,
                  quantity: 1,
                );
                ref.read(cartProvider.notifier).addItem(cartItem);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${item.name} added to cart!"),
                    backgroundColor: Colors.green,
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }
}
