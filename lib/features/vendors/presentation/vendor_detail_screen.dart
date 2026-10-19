import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/models/vendor.dart';
import '../../../core/providers/vendor_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/vendor_cart_button.dart';
import 'widgets/vendor_detail_app_bar.dart';
import 'widgets/vendor_info_header.dart';
import 'widgets/vendor_item_row.dart';

/// Catalogue for one shop of any generic category (florist, pet shop…),
/// top to bottom:
///
///   VendorDetailAppBar   photo
///   VendorInfoHeader     name, description, rating / time / fee, "closed"
///   one section per in-shop category ("Roses", "Croquettes"):
///     title + list of VendorItemRow
///   VendorCartButton     floating, once the cart has something
///
/// Each row adds straight to the shared cart — the same cart the food and
/// grocery flows use.
class VendorDetailScreen extends ConsumerWidget {
  final Vendor vendor;

  const VendorDetailScreen({super.key, required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(vendorItemsProvider(vendor.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          VendorDetailAppBar(vendor: vendor),
          SliverToBoxAdapter(child: VendorInfoHeader(vendor: vendor)),
          ...itemsAsync.when(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            ],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: _CatalogueError(
                  onRetry: () => ref.invalidate(vendorItemsProvider(vendor.id)),
                ),
              )
            ],
            data: (items) => items.isEmpty
                ? [const SliverToBoxAdapter(child: _NoItemsYet())]
                : _catalogueSections(
                    items, AppLocalizations.of(context)!.vendorDefaultSection),
          ),
        ],
      ),
      // Same floating cart bar the food and grocery catalogues use, so a
      // shop order is as obviously checkout-able as a restaurant one.
      floatingActionButton: const VendorCartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// One title + list per in-shop section, in the order the rows came back
  /// (sort_order), so the shop controls how its catalogue reads.
  List<Widget> _catalogueSections(
      List<VendorItem> items, String defaultSection) {
    final grouped = <String, List<VendorItem>>{};
    for (final item in items) {
      final key = (item.category?.trim().isNotEmpty ?? false)
          ? item.category!.trim()
          : defaultSection;
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return [
      for (final entry in grouped.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              entry.key,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => VendorItemRow(
              item: entry.value[i],
              enabled: vendor.isOpen,
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }
}

/// "Impossible de charger le catalogue" + Réessayer.
class _CatalogueError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CatalogueError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 36, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text(AppLocalizations.of(context)!.vendorCatalogueLoadError,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }
}

/// "Aucun article pour le moment."
class _NoItemsYet extends StatelessWidget {
  const _NoItemsYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.vendorNoItemsYet,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
