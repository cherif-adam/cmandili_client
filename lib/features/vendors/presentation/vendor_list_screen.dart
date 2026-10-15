import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/providers/vendor_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/vendor_card.dart';

/// Shop list for any vendor category — florists, pet shops, gift shops,
/// bakeries, electronics stores — shown in the home tab:
///
///   list of VendorCard   (nearest first, within 15 km)
///   or _NoShopsYet / _ShopsError
///
/// One screen serves every category: the only thing that changes is the
/// `category` string it is given. Returns a sliver.
class VendorListScreen extends ConsumerWidget {
  /// `vendors.category` value to list.
  final String category;

  /// Shown in the empty state so it reads naturally per category
  /// ("Aucun fleuriste disponible").
  final String emptyLabel;

  const VendorListScreen({
    super.key,
    required this.category,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(nearbyVendorsByCategoryProvider(category));

    return vendorsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: _ShopsError(
          onRetry: () => ref.invalidate(vendorsByCategoryProvider(category)),
        ),
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return SliverToBoxAdapter(child: _NoShopsYet(label: emptyLabel));
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          sliver: SliverList.separated(
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => VendorCard(vendor: vendors[i]),
          ),
        );
      },
    );
  }
}

/// "Impossible de charger les boutiques" + Réessayer.
class _ShopsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ShopsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 40, color: AppColors.textLight),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.couldNotLoadShops,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
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

/// "Aucun fleuriste disponible près de vous." + "Revenez bientôt…"
class _NoShopsYet extends StatelessWidget {
  final String label;

  const _NoShopsYet({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined,
              size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.newShopsSoon,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
