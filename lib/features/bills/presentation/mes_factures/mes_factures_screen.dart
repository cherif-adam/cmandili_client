import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../orders/data/models/order.dart';
import '../../../orders/providers/order_provider.dart';
import 'widgets/empty_factures_view.dart';
import 'widgets/facture_history_card.dart';

/// "Mes factures": the bill payments the customer asked for, newest first.
///
///   AppBar "Mes factures"
///   _FacturesList (pull to refresh) of FactureHistoryCard
///   or EmptyFacturesView / _FacturesError
///
/// UI only: the orders come from [billOrdersProvider] (OrderRepository).
class MesFacturesScreen extends ConsumerWidget {
  const MesFacturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(billOrdersProvider);
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.billsTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return EmptyFacturesView(sw: sw, sh: sh);
          return _FacturesList(
            orders: orders,
            onRefresh: () async => ref.invalidate(billOrdersProvider),
            sw: sw,
            sh: sh,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF9500))),
        error: (e, _) => _FacturesError(
          onRetry: () => ref.invalidate(billOrdersProvider),
          sw: sw,
          sh: sh,
        ),
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Pull-to-refresh list of FactureHistoryCard.
class _FacturesList extends StatelessWidget {
  const _FacturesList({
    required this.orders,
    required this.onRefresh,
    required this.sw,
    required this.sh,
  });

  final List<Order> orders;
  final RefreshCallback onRefresh;
  final double sw;
  final double sh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFFF9500),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(sw * 0.04, sh * 0.01, sw * 0.04, sh * 0.04),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            FactureHistoryCard(order: orders[index], sw: sw, sh: sh),
      ),
    );
  }
}

/// "Impossible de charger les factures" with a retry button.
class _FacturesError extends StatelessWidget {
  const _FacturesError({required this.onRetry, required this.sw, required this.sh});

  final VoidCallback onRetry;
  final double sw;
  final double sh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(sw * 0.1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: sw * 0.15, color: AppColors.error),
            SizedBox(height: sh * 0.02),
            Text(AppLocalizations.of(context)!.billsLoadError,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: sh * 0.02),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
