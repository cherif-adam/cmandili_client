import 'package:flutter/material.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/models/vendor.dart';

/// La coquille commune aux deux écrans d'offres : bannière, titre, onglets.
///
/// HAPPY HOUR et PROMOS ne diffèrent que par leurs catégories, leur couleur et
/// leur image. Tout le reste — la mise en page de l'en-tête, la barre
/// d'onglets, le bouton panier — est le même, et le rester est le seul moyen
/// que les deux écrans ne divergent pas à la première retouche.
///
/// Les onglets viennent de [categories], donc de `discount_mode` en base :
/// aucun nom de catégorie n'est écrit dans le code de l'interface, et les
/// libellés sont ceux de `vendor_categories` dans la langue du client.
class DealsScaffold extends StatefulWidget {
  const DealsScaffold({
    super.key,
    required this.categories,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundImage,
    required this.tabBuilder,
    this.initialTab = 0,
    this.initialCategoryId,
    this.floatingActionButton,
  });

  final List<VendorCategory> categories;
  final String title;
  final String subtitle;
  final Color accentColor;
  final String backgroundImage;
  final Widget Function(VendorCategory category) tabBuilder;
  final int initialTab;

  /// Catégorie à ouvrir, quand l'appelant la connaît mieux qu'un numéro
  /// d'onglet : une notification, ou une offre tapée sur la bannière.
  ///
  /// Un index d'onglet ne veut rien dire hors de cet écran, et change dès
  /// qu'une catégorie est masquée ou bascule de mode. La catégorie, elle,
  /// reste juste. Résolue ici, là où la liste est connue, pour qu'aucun
  /// appelant n'ait à la traduire.
  final String? initialCategoryId;

  final Widget? floatingActionButton;

  @override
  State<DealsScaffold> createState() => _DealsScaffoldState();
}

class _DealsScaffoldState extends State<DealsScaffold>
    with TickerProviderStateMixin {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant DealsScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La liste d'onglets vient de la base : elle peut changer de longueur en
    // cours de route (catégorie masquée, mode basculé). Un TabController dont
    // la longueur ne correspond plus lève une assertion, d'où cette remise à
    // niveau plutôt qu'un contrôleur créé une fois dans initState.
    if (oldWidget.categories.length != widget.categories.length) {
      _syncController();
    }
  }

  void _syncController() {
    final length = widget.categories.length;
    if (length == 0) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    if (_controller != null && _controller!.length == length) return;
    final previousIndex = _controller?.index ?? _startIndex();
    _controller?.dispose();
    _controller = TabController(
      length: length,
      vsync: this,
      initialIndex: previousIndex.clamp(0, length - 1),
    );
  }

  int _startIndex() {
    final id = widget.initialCategoryId;
    if (id != null && id.isNotEmpty) {
      final i = widget.categories.indexWhere((c) => c.id == id);
      if (i >= 0) return i;
    }
    return widget.initialTab;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.noDealsRightNow),
        ),
      );
    }

    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 4,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 60),
              centerTitle: false,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
                      shadows: [
                        Shadow(
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.backgroundImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: widget.accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: ColoredBox(
                color: Colors.white,
                child: TabBar(
                  controller: controller,
                  isScrollable: widget.categories.length > 3,
                  tabAlignment: widget.categories.length > 3
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  indicatorColor: widget.accentColor,
                  indicatorWeight: 3,
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: [
                    for (final c in widget.categories)
                      Tab(text: '${c.icon}  ${c.localizedName(languageCode)}'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: controller,
          children: [
            for (final c in widget.categories) widget.tabBuilder(c),
          ],
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
