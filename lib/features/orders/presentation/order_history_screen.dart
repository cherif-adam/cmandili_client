import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/order_provider.dart';
import 'widgets/empty_orders_view.dart';
import 'widgets/loyalty_progress_card.dart';
import 'widgets/order_history_card.dart';
import 'widgets/orders_error_view.dart';

/// The customer's orders, newest first (the "Commandes" tab):
///
///   LoyaltyProgressCard   "3/5 commandes avant votre prochaine réduction"
///   list of OrderHistoryCard
///   or EmptyOrdersView / OrdersErrorView
///
/// Pull down to refresh.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);
    final loyaltyAsync = ref.watch(loyaltyProgressProvider);
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.orderHistory,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return EmptyOrdersView(sw: sw, sh: sh);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userOrdersProvider);
              ref.invalidate(loyaltyProgressProvider);
            },
            color: AppColors.primary,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(sw * 0.04, sh * 0.01, sw * 0.04, sh * 0.04),
              itemCount: orders.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return loyaltyAsync.when(
                    data: (count) => LoyaltyProgressCard(count: count, sw: sw, sh: sh),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                }
                return OrderHistoryCard(order: orders[index - 1], sw: sw, sh: sh);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => OrdersErrorView(
          error: error,
          onRetry: () => ref.invalidate(userOrdersProvider),
          sw: sw,
          sh: sh,
        ),
      ),
    );
  }
}
