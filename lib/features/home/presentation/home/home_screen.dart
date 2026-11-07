import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/bottom_reserve.dart';
import '../../../ai_onboarding/presentation/widgets/ai_onboarding_host.dart';
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
/// Edge-to-edge: the system navigation bar is under the screen. Everything
/// floating sits above it, placed by one [HomeBottomLayout]; the tabs get
/// the room to leave after their last item through [BottomReserve].
///
/// Wrapped in AiOnboardingHost: the one-time AI coach mark and the home
/// list's scroll that extends/collapses the assistant button.
///
/// UI only: the selected tab and the bottom layout live in
/// [HomeController]; the AI entry points' rules in AiOnboardingController.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenHeight = size.height;
    final screenWidth = size.width;
    final cartItemCount = ref.watch(cartItemCountProvider);
    final selectedIndex = ref.watch(homeControllerProvider);
    final layout = HomeBottomLayout(
      systemBottom: MediaQuery.viewPaddingOf(context).bottom,
      navHeight: screenHeight * 0.085,
      pillShowing: ref.watch(activeOrderPillShowingProvider),
    );

    return AiOnboardingHost(
      onHomeTab: selectedIndex == 0,
      child: Scaffold(
        // The assistant belongs to browsing. On the other tabs it sat on top
        // of the cart's checkout button and the profile list.
        floatingActionButton:
            selectedIndex == 0 ? AiChatFab(bottomLift: layout.fabLift) : null,
        body: Stack(
          children: [
            BottomReserve(
              bottom: layout.contentBottom,
              child: _TabsStack(
                selectedIndex: selectedIndex,
                cartInset: layout.floatingRoom,
              ),
            ),
            ActiveOrderPill(
              bottom: layout.pillBottom,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
            HomeBottomNavBar(
              bottom: layout.navBottom,
              height: layout.navHeight,
              selectedIndex: selectedIndex,
              cartItemCount: cartItemCount,
              onSelect: ref.read(homeControllerProvider.notifier).selectTab,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ],
        ),
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
        // The home tab's animations (typewriter, sparkle, shimmer) stop
        // while another tab is shown.
        TickerMode(enabled: selectedIndex == 0, child: const HomeTab()),
        const FavoritesScreen(),
        const OrderHistoryScreen(),
        CartScreen(bottomInset: cartInset),
        const ProfileScreen(),
      ],
    );
  }
}
