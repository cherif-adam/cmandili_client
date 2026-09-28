import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../happy_hour/presentation/widgets/deals_home_banner.dart';
import '../../../happy_hour/providers/deal_categories_provider.dart';
import '../promos_screen.dart';

/// Point d'entrée PROMOS sur l'accueil : la jumelle bleue de la bannière
/// Happy Hour.
///
/// Elle ne liste que les offres des catégories en `discount_mode = 'percent'`
/// — supermarché, fleurs, animalerie, cadeaux, électronique aujourd'hui. Le
/// bleu n'est pas décoratif : il dit au client, avant même de lire, qu'il
/// s'agit d'une remise en pourcentage et non d'un prix de soirée.
class PromosHomeBanner extends ConsumerWidget {
  const PromosHomeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return DealsHomeBanner(
      deals: ref.watch(promosBannerDealsProvider),
      title: l.promos,
      // Le même gabarit de résumé que le Happy Hour : « 3 offres · jusqu'à
      // -40 % ». Le mot « offre » vaut pour les deux, et une clé de plus par
      // langue pour dire la même chose se serait désynchronisée.
      summary: l.happyHourDealsSummary,
      noDealsLabel: l.happyHourNoDealsNow,
      liveLabel: l.happyHourLive,
      ctaLabel: l.promosBannerCta,
      accentColor: kPromosAccent,
      backgroundImage: 'assets/images/promos_banner.jpg',
      fallbackGradient: const LinearGradient(
        colors: [Color(0xFF60A5FA), kPromosAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      // Voile bleu à gauche, transparent à droite : le texte reste lisible
      // sans noyer la photo, comme sur la bannière orange.
      overlayGradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xA61E3A8A), Color(0x001E3A8A)],
        stops: [0.0, 0.55],
      ),
      onOpen: (categoryId) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PromosScreen(initialCategoryId: categoryId),
        ),
      ),
    );
  }
}
