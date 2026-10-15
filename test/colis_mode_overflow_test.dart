// Le badge « Recommandé » ajoute du contenu dans une Row déjà occupée par le
// titre du mode, et le nouveau titre de section est bien plus long que
// l'ancien. C'est exactement l'endroit où un débordement apparaît : la barre
// de l'assistant avait déjà débordé de 9,7 px pour la même raison.
//
// ── CE QUE CES TESTS MESURENT ────────────────────────────────────────────────
// La géométrie réelle des éléments ajoutés ou rallongés : restent-ils dans
// l'écran, à quatre largeurs de téléphone. On ne se contente pas de
// `takeException() == null`, et c'est volontaire :
//
// L'ÉCRAN COLIS DÉBORDE DÉJÀ AILLEURS, AVANT CE CHANGEMENT. Mesuré sur la
// version précédente, aux largeurs 320/360/393/430 : une vingtaine de
// RenderFlex en débordement, de 9,8 px à 121 px. Il en reste quatre à droite
// (18, 23, 26 et 31 px, une Row d'un champ à `Align`) et deux en bas (0,1 px
// et 9,8 px, une carte à hauteur fixe de 124 px) — tous présents avant et
// après, aucun dans la section de remise. Un test global échouerait donc sur
// des défauts qui ne sont pas les nôtres, et il serait désactivé au premier
// agacement. Celui-ci consomme ces erreurs et mesure ce dont ce changement
// répond.
//
// Ce qui A été corrigé ici, parce que ce changement l'avait aggravé :
// _buildSectionHeader n'avait aucune contrainte sur son titre. Plusieurs
// en-têtes débordaient de 37 à 48 px ; « Comment le livreur remet votre
// colis ? » portait le débordement à plus de 250 px. Avec l'Expanded, tous
// les en-têtes de la page tiennent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/features/courier/presentation/courier_screen.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _widths = [320.0, 360.0, 393.0, 430.0];

Future<AppLocalizations> pumpCourier(
  WidgetTester tester, {
  required double width,
  String locale = 'fr',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CourierScreen(screenWidth: width, screenHeight: 900),
      ),
    ),
  ));
  // pumpAndSettle est exclu : l'écran lance des lectures réseau au montage,
  // qui n'aboutissent pas en test. Un pump suffit pour obtenir le layout.
  await tester.pump();

  // Les débordements préexistants décrits en tête de fichier. Les laisser
  // ferait échouer le test au démontage sur des défauts d'ailleurs.
  tester.takeException();

  return AppLocalizations.delegate.load(Locale(locale));
}

/// Un texte tient-il entièrement dans la largeur de l'écran ?
void expectWithinScreen(
  WidgetTester tester,
  Finder finder,
  double width,
  String what,
) {
  expect(finder, findsOneWidget, reason: '$what est absent');
  final left = tester.getTopLeft(finder).dx;
  final right = tester.getBottomRight(finder).dx;
  expect(left, greaterThanOrEqualTo(-0.5), reason: '$what sort à gauche');
  expect(right, lessThanOrEqualTo(width + 0.5),
      reason: '$what dépasse de ${(right - width).toStringAsFixed(1)} px');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  group('le choix du mode de remise tient à l\'écran', () {
    for (final width in _widths) {
      testWidgets('titre et badge dans l\'écran à ${width.toInt()} px',
          (tester) async {
        final l10n = await pumpCourier(tester, width: width);

        expectWithinScreen(tester, find.text(l10n.colisHandoverSectionTitle),
            width, 'le titre de section');
        expectWithinScreen(tester, find.text(l10n.colisModeRecommended), width,
            'le badge Recommandé');
        expectWithinScreen(tester, find.text(l10n.colisModeCodeTitle), width,
            'le titre « Avec code »');
        expectWithinScreen(tester, find.text(l10n.colisModeNoCodeTitle), width,
            'le titre « Remise sans code »');
      });
    }

    testWidgets('le titre de section passe à la ligne au lieu de déborder',
        (tester) async {
      // 320 px est la largeur où l'ancien en-tête débordait le plus.
      final l10n = await pumpCourier(tester, width: 320);
      final title = find.text(l10n.colisHandoverSectionTitle);
      expectWithinScreen(tester, title, 320, 'le titre de section');
      // Deux lignes à cette largeur : s'il tenait sur une, c'est qu'il aurait
      // été tronqué ou réduit.
      final size = tester.getSize(title);
      expect(size.height, greaterThan(20),
          reason: 'le titre ne s\'enroule pas, il est donc coupé');
    });

    testWidgets('le badge n\'apparaît que sur le mode recommandé',
        (tester) async {
      final l10n = await pumpCourier(tester, width: 360);
      expect(find.text(l10n.colisModeRecommended), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget,
          reason: 'le cadenas signale le mode protégé');
    });

    testWidgets('les explications des deux modes ne sont pas tronquées',
        (tester) async {
      final l10n = await pumpCourier(tester, width: 360);

      // Pas de maxLines ni d'ellipse : une explication coupée à « Sans le bon
      // code, le livreur ne peut… » perd précisément ce qu'elle disait.
      for (final s in [l10n.colisModeCodeSubtitle, l10n.colisModeNoCodeSubtitle]) {
        final w = tester.widget<Text>(find.text(s));
        expect(w.maxLines, isNull, reason: 'texte tronqué : $s');
        expect(w.overflow, anyOf(isNull, TextOverflow.clip));
      }
    });

    testWidgets('l\'arabe tient aussi, en RTL et à 320 px', (tester) async {
      final l10n = await pumpCourier(tester, width: 320, locale: 'ar');
      expectWithinScreen(tester, find.text(l10n.colisHandoverSectionTitle), 320,
          'le titre arabe');
      expectWithinScreen(
          tester, find.text(l10n.colisModeRecommended), 320, 'le badge arabe');
    });
  });
}
