import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../cart/presentation/widgets/cart_fab.dart';
import '../../happy_hour/presentation/widgets/deals_scaffold.dart';
import '../../happy_hour/presentation/widgets/deals_tab.dart';
import '../../happy_hour/providers/deal_categories_provider.dart';

/// Le bleu des promotions, partagé avec sa bannière d'accueil. Il distingue
/// d'un coup d'œil une remise en pourcentage d'un Happy Hour, qui est orange.
const Color kPromosAccent = Color(0xFF2563EB);

/// Les offres des commerces qui remisent en pourcentage : supermarché,
/// fleuriste, animalerie, cadeaux, électronique.
///
/// Même écran que le Happy Hour dans sa forme — c'est le même
/// [DealsScaffold] et les mêmes cartes — mais pas dans son fond. Un Happy
/// Hour est un prix posé pour la soirée ; une promotion est un taux appliqué
/// entre deux dates, qu'un commerçant programme à l'avance. Les mélanger sur
/// un seul écran obligeait à écrire « nourriture et épicerie » sous un titre
/// qui listait des fleuristes.
///
/// La répartition vient de `vendor_categories.discount_mode`, jamais d'une
/// liste de catégories écrite ici : basculer les fleurs en Happy Hour est un
/// UPDATE, et leur onglet change d'écran tout seul.
class PromosScreen extends ConsumerWidget {
  const PromosScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return DealsScaffold(
      categories: ref.watch(percentCategoriesProvider),
      title: l.promos,
      subtitle: l.promosSubtitle,
      accentColor: kPromosAccent,
      // Le visuel du supermarche, premiere categorie en pourcentage. Une
      // image dediee peut le remplacer ici sans rien changer d'autre.
      backgroundImage: 'assets/images/amana_supermarket_hero.jpg',
      initialTab: initialTab,
      tabBuilder: (category) => DealsTab(
        category: category,
        accentColor: kPromosAccent,
      ),
      floatingActionButton: const CartFab(backgroundColor: kPromosAccent),
    );
  }
}
