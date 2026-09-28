import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/deal_categories_provider.dart';
import '../happy_hour_screen.dart';
import 'deals_home_banner.dart';

const Color _kHappyOrange = Color(0xFFFF9500);

/// Point d'entrée Happy Hour sur l'accueil.
///
/// La bannière était une image fixe, identique qu'il y ait zéro offre ou
/// vingt : le client n'avait aucun moyen de savoir qu'un Happy Hour tournait.
/// Elle le dit maintenant — badge EN DIRECT, nombre réel d'offres et
/// meilleure remise, compte à rebours, et la rangée des offres en cours juste
/// dessous.
///
/// Elle ne liste que les offres des catégories en `discount_mode =
/// 'happy_hour'`. Les autres ont leur propre bannière, [PromosHomeBanner] :
/// une offre de supermarché ici ouvrirait un écran où son onglet n'existe
/// plus.
class HappyHourHomeBanner extends ConsumerWidget {
  const HappyHourHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final categories = ref.watch(happyHourCategoriesProvider);

    return DealsHomeBanner(
      deals: ref.watch(happyHourBannerDealsProvider),
      title: l.happyHour,
      summary: l.happyHourDealsSummary,
      noDealsLabel: l.happyHourNoDealsNow,
      liveLabel: l.happyHourLive,
      ctaLabel: l.viewDeals,
      accentColor: _kHappyOrange,
      backgroundImage: 'assets/images/happy_hour_banner.jpg',
      fallbackGradient: const LinearGradient(
        colors: [Color(0xFFFFCC00), _kHappyOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      overlayGradient: AppColors.happyHourOverlayGradient,
      onOpen: (categoryId) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HappyHourScreen(
            initialTab: tabIndexFor(categories, categoryId),
          ),
        ),
      ),
    );
  }
}
