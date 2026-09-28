import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../cart/presentation/widgets/cart_fab.dart';
import '../providers/deal_categories_provider.dart';
import 'widgets/deals_scaffold.dart';
import 'widgets/deals_tab.dart';

/// L'orange du Happy Hour, partagé avec sa bannière d'accueil.
const Color kHappyHourAccent = Color(0xFFFF6D00);

/// Les offres des commerces qui font du Happy Hour : un prix réduit, posé
/// tout de suite, pour quelques heures.
///
/// Ses onglets ne sont pas écrits ici. Ce sont les catégories dont
/// `vendor_categories.discount_mode` vaut `'happy_hour'` — aujourd'hui les
/// restaurants et les pâtisseries. Les commerces en pourcentage ont leur
/// propre écran, PromosScreen : deux gestes de commerce différents, deux
/// écrans, et la base qui tranche lequel.
class HappyHourScreen extends ConsumerWidget {
  const HappyHourScreen({super.key, this.initialTab = 0});

  /// Onglet ouvert à l'arrivée. L'index porte sur les onglets DE CET ÉCRAN et
  /// il est borné : une notification émise avant la séparation des deux
  /// écrans pouvait valoir 2 (l'ancien onglet « Boutiques »), et ouvre
  /// désormais le dernier onglet existant au lieu de faire échouer le
  /// contrôleur.
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return DealsScaffold(
      categories: ref.watch(happyHourCategoriesProvider),
      title: l.happyHour,
      subtitle: l.happyHourSubtitle,
      accentColor: kHappyHourAccent,
      backgroundImage: 'assets/images/happy_hour_banner.jpg',
      initialTab: initialTab,
      tabBuilder: (category) => DealsTab(
        category: category,
        accentColor: kHappyHourAccent,
      ),
      floatingActionButton: const CartFab(backgroundColor: kHappyHourAccent),
    );
  }
}
