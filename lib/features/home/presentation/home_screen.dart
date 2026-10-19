import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/presentation/cart/cart_screen.dart';
import '../../cart/providers/cart_provider.dart';
import '../../favorites/presentation/favorites/favorites_screen.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../orders/providers/order_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import 'home_tab.dart';
import 'widgets/active_order_pill.dart';
import 'widgets/ai_chat_fab.dart';
import 'widgets/home_bottom_nav_bar.dart';

/// The app's main screen: five tabs under a floating menu bar.
///
///   Stack
///   ├─ IndexedStack — the selected tab
///   │   ├─ HomeTab            (0) shops, banners, categories
///   │   ├─ FavoritesScreen    (1)
///   │   ├─ OrderHistoryScreen (2)
///   │   ├─ CartScreen         (3)
///   │   └─ ProfileScreen      (4)
///   ├─ ActiveOrderPill — back into order tracking, on every tab
///   └─ HomeBottomNavBar
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final cartItemCount = ref.watch(cartItemCountProvider);

    // The cart tab ends in its own summary and checkout button: keep them
    // clear of the menu bar, and of the active-order pill when it shows.
    final pillShowing =
        ref.watch(receiptPendingOrderProvider).valueOrNull != null ||
            ref.watch(activeOrderProvider).valueOrNull != null;
    final cartInset = screenHeight * (0.125 + (pillShowing ? 0.075 : 0));

    return Scaffold(
      // The assistant belongs to browsing. On the other tabs it sat on top
      // of the cart's checkout button and the profile list.
      floatingActionButton: _selectedIndex == 0 ? const AiChatFab() : null,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              const HomeTab(),
              const FavoritesScreen(),
              const OrderHistoryScreen(),
              CartScreen(bottomInset: cartInset),
              const ProfileScreen(),
            ],
          ),
          ActiveOrderPill(screenWidth: screenWidth, screenHeight: screenHeight),
          HomeBottomNavBar(
            selectedIndex: _selectedIndex,
            cartItemCount: cartItemCount,
            onSelect: (index) => setState(() => _selectedIndex = index),
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        ],
      ),
    );
  }
}
