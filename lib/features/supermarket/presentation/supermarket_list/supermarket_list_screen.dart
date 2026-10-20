import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/providers/nearby_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/supermarket.dart';
import '../../providers/supermarket_provider.dart';
import 'widgets/supermarket_card.dart';
import 'widgets/supermarket_hero_banner.dart';

/// The supermarkets part of the home tab (shown when "Supermarché" is
/// picked):
///
///   SupermarketHeroBanner   "Faire ses courses"
///   list of SupermarketCard (nearest first, within 15 km)
///
/// Returns slivers, so it goes in the home tab's [CustomScrollView].
/// UI only: the list comes from [nearbySupermarketsProvider]
/// (ShopRepository behind it).
class SupermarketListScreen extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const SupermarketListScreen({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supermarketsAsync = ref.watch(nearbySupermarketsProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: screenHeight * 0.015),
            child: SupermarketHeroBanner(screenWidth: screenWidth),
          ),
        ),
        supermarketsAsync.when(
          data: (supermarkets) => supermarkets.isEmpty
              ? SliverToBoxAdapter(
                  child: _NoSupermarketsNearby(
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                )
              : _SupermarketsSliverList(
                  supermarkets: supermarkets,
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
          loading: () => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(screenHeight * 0.05),
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
          error: (error, stack) => SliverToBoxAdapter(
            child: _SupermarketsError(
              onRetry: () => ref.invalidate(supermarketsProvider),
              screenHeight: screenHeight,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One SupermarketCard per supermarket, nearest first.
class _SupermarketsSliverList extends StatelessWidget {
  final List<Supermarket> supermarkets;
  final double screenWidth;
  final double screenHeight;

  const _SupermarketsSliverList({
    required this.supermarkets,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        0,
        screenWidth * 0.05,
        screenHeight * 0.12,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => SupermarketCard(
            supermarket: supermarkets[index],
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
          childCount: supermarkets.length,
        ),
      ),
    );
  }
}

/// "Aucun supermarché à moins de 15 km de vous pour le moment."
class _NoSupermarketsNearby extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;

  const _NoSupermarketsNearby({
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(screenHeight * 0.05),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined,
              size: screenWidth * 0.12, color: Colors.grey[400]),
          SizedBox(height: screenHeight * 0.02),
          Text(
            AppLocalizations.of(context)!
                .noSupermarketsNearby(kShopRadiusKm.round()),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Impossible de charger les supermarchés" + Réessayer.
class _SupermarketsError extends StatelessWidget {
  final VoidCallback onRetry;
  final double screenHeight;

  const _SupermarketsError({required this.onRetry, required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenHeight * 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            SizedBox(height: screenHeight * 0.02),
            Text(AppLocalizations.of(context)!.couldNotLoadSupermarkets,
                style: const TextStyle(fontSize: 16)),
            SizedBox(height: screenHeight * 0.02),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
