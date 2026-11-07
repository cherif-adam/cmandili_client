import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/models/vendor.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/dish_spotlight.dart';
import 'vendor_detail_controller.dart';
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
/// grocery flows use. Opened from a chat result, the page scrolls to
/// [highlightItemId] and makes that product glow a moment (DishSpotlight).
/// UI only: the catalogue, its grouping and the retry live in
/// [VendorDetailController].
class VendorDetailScreen extends ConsumerStatefulWidget {
  final Vendor vendor;

  /// The product to scroll to and make glow, when opened from a result.
  final String? highlightItemId;

  const VendorDetailScreen({super.key, required this.vendor, this.highlightItemId});

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  final _scrollController = ScrollController();
  late final _spotlight = DishSpotlight(widget.highlightItemId);

  @override
  void dispose() {
    _spotlight.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendor = widget.vendor;
    final itemsAsync = ref.watch(vendorDetailControllerProvider(vendor.id));
    final controller = ref.read(vendorDetailControllerProvider(vendor.id).notifier);
    // Once the catalogue is on screen, if the product is in it (it may have
    // sold out since); the spotlight only runs the first time.
    if (itemsAsync.valueOrNull?.any((item) => item.id == widget.highlightItemId) ??
        false) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _spotlight.reveal(_scrollController));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
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
                child: _CatalogueError(onRetry: controller.retry),
              )
            ],
            data: (items) => items.isEmpty
                ? [const SliverToBoxAdapter(child: _NoItemsYet())]
                : [
                    for (final section in controller
                        .sections(items,
                            AppLocalizations.of(context)!.vendorDefaultSection)
                        .entries)
                      _CatalogueSection(
                        title: section.key,
                        items: section.value,
                        enabled: vendor.isOpen,
                        spotlight: _spotlight,
                      ),
                    // Room for the cart button, above the system bar.
                    SliverToBoxAdapter(
                      child: SizedBox(height: 100 + MediaQuery.paddingOf(context).bottom),
                    ),
                  ],
          ),
        ],
      ),
      // Same floating cart bar the food and grocery catalogues use, so a
      // shop order is as obviously checkout-able as a restaurant one.
      floatingActionButton: const VendorCartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One in-shop section: its title, then one VendorItemRow per item, the
/// searched one (if any) inside the spotlight's glow.
class _CatalogueSection extends StatelessWidget {
  final String title;
  final List<VendorItem> items;
  final bool enabled;
  final DishSpotlight spotlight;

  const _CatalogueSection({
    required this.title,
    required this.items,
    required this.enabled,
    required this.spotlight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => spotlight.frame(
              items[i].id,
              VendorItemRow(
                item: items[i],
                enabled: enabled,
              ),
              // VendorItemRow's own corners.
              radius: 14,
            ),
          ),
        ),
      ],
    );
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
