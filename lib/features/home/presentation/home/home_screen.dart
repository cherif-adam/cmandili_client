import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cart/presentation/cart/cart_screen.dart';
import '../../../cart/providers/cart_provider.dart';
import '../../../favorites/presentation/favorites/favorites_screen.dart';
import '../../../orders/presentation/order_history/order_history_screen.dart';
import '../../../profile/presentation/profile/profile_screen.dart';
import '../home_tab/home_tab.dart';
import 'home_controller.dart';
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
///
/// UI only: the selected tab and the cart's bottom room live in
/// [HomeController].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final cartItemCount = ref.watch(cartItemCountProvider);
    final selectedIndex = ref.watch(homeControllerProvider);
    final cartInset = HomeController.cartBottomInset(
      screenHeight,
      pillShowing: ref.watch(activeOrderPillShowingProvider),
    );

    return Scaffold(
      // The assistant belongs to browsing. On the other tabs it sat on top
      // of the cart's checkout button and the profile list.
      floatingActionButton: selectedIndex == 0 ? const AiChatFab() : null,
      body: Stack(
        children: [
          _TabsStack(selectedIndex: selectedIndex, cartInset: cartInset),
          ActiveOrderPill(screenWidth: screenWidth, screenHeight: screenHeight),
          HomeBottomNavBar(
            selectedIndex: selectedIndex,
            cartItemCount: cartItemCount,
            onSelect: ref.read(homeControllerProvider.notifier).selectTab,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        ],
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// The five tabs; only the selected one is shown, the others keep their
/// state.
class _TabsStack extends StatelessWidget {
  const _TabsStack({required this.selectedIndex, required this.cartInset});

  final int selectedIndex;
  final double cartInset;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        const HomeTab(),
        const FavoritesScreen(),
        const OrderHistoryScreen(),
        CartScreen(bottomInset: cartInset),
        const ProfileScreen(),
      ],
    );
  }
}
