import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/utils/platform_pricing.dart';
import '../providers/happy_hour_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../cart/data/models/cart_item.dart';
import '../../cart/presentation/add_to_cart_guard.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';
import 'widgets/happy_hour_card.dart';

class HappyHourScreen extends ConsumerStatefulWidget {
  const HappyHourScreen({super.key, this.initialTab = 0});

  /// 0 = Restaurants, 1 = Supermarchés, 2 = Boutiques (every other shop
  /// category). Lets a tapped deal on the home screen land on its tab.
  final int initialTab;

  @override
  ConsumerState<HappyHourScreen> createState() => _HappyHourScreenState();
}

class _HappyHourScreenState extends ConsumerState<HappyHourScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
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
                          Shadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.saveUpTo60,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/happy_hour_banner.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          Container(color: Colors.orange.shade200),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.7),
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
                      Tab(text: AppLocalizations.of(context)!.happyHourShopsTab),
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
            _buildShopsList(),
          ],
        ),
      ),
      floatingActionButton: _cartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Ajoute l'offre au panier et ouvre la voie vers la suite.
  ///
  /// Sans l'action « Voir le panier », le client voyait passer un message et
  /// restait sur l'écran des offres : rien ne menait à la commande. Le
  /// message dure assez longtemps pour être touché -- 1,5 s ne suffisait pas.
  Future<void> _grab(CartItem cartItem, String itemName) async {
    final l = AppLocalizations.of(context)!;
    final added = await addToCartGuarded(context, ref, cartItem);
    if (!added || !mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.happyHourAddedToCart(itemName)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l.viewCart,
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ),
      );
  }

  /// Bouton panier, visible dès qu'il y a quelque chose dedans.
  ///
  /// Le message disparaît, ce bouton reste : c'est lui qui garantit qu'un
  /// client ayant pris trois offres d'affilée retrouve le chemin de la
  /// commande. Il ouvre le panier normal, donc la suite est celle de
  /// n'importe quelle commande -- adresse, frais, confirmation, suivi.
  Widget? _cartButton() {
    final count = ref.watch(cartItemCountProvider);
    if (count == 0) return null;
    final l = AppLocalizations.of(context)!;
    final total = ref.watch(cartTotalProvider);

    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      ),
      backgroundColor: Colors.deepOrange,
      foregroundColor: Colors.white,
      icon: Badge(
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_rounded),
      ),
      label: Text(
        '${l.viewCart}  ·  ${CurrencyFormatter.formatPrice(total)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
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
              originalPrice: applyPlatformMarkup(item.price),
              discountPrice: item.clientPrice,
              discountEndTime: item.discountEndTime,
              discountQuantity: item.discountQuantity,
              onTap: () {},
              onGrab: () => _grab(
                CartItem.restaurant(foodItem: item, quantity: 1),
                item.name,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text(AppLocalizations.of(context)!.happyHourLoadError)),
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
              originalPrice: applyPlatformMarkup(item.price),
              discountPrice: item.clientPrice,
              discountEndTime: item.discountEndTime,
              discountQuantity: item.discountQuantity,
              onTap: () {},
              onGrab: () => _grab(
                CartItem.grocery(groceryItem: item, quantity: 1),
                item.name,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text(AppLocalizations.of(context)!.happyHourLoadError)),
    );
  }

  /// Gift shops, florists, pet shops, bakeries, electronics — items that only
  /// exist in vendor_items. Same card, cart line typed as a vendor item.
  Widget _buildShopsList() {
    final asyncValue = ref.watch(happyHourShopsProvider);
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
              originalPrice: applyPlatformMarkup(item.price),
              discountPrice: applyPlatformMarkup(item.effectivePrice),
              discountEndTime: item.discountEndTime,
              discountQuantity: item.discountQuantity,
              onTap: () {},
              onGrab: () => _grab(
                CartItem.vendor(vendorItem: item, quantity: 1),
                item.name,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text(AppLocalizations.of(context)!.happyHourLoadError)),
    );
  }
}
