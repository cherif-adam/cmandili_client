// L'écran Colis tient-il dans l'écran ?
//
// ── POURQUOI CE FICHIER ──────────────────────────────────────────────────────
// Trois débordements distincts ont été corrigés sur cette page, et aucun ne
// s'était vu avant qu'on mesure :
//
//   1. _buildSectionHeader ne contraignait pas son titre. Plusieurs en-têtes
//      débordaient de 37 à 48 px, et le titre « Comment le livreur remet votre
//      colis ? », plus long, portait le débordement à plus de 250 px.
//   2. La Row du bouton d'envoi débordait de 18 à 31 px dès que le prix estimé
//      s'affichait à côté du libellé.
//   3. Le cadre « Ajouter une photo du colis » était dimensionné par la
//      HAUTEUR de l'écran (h * 0.14) alors que son contenu est dimensionné par
//      la LARGEUR : il débordait par le bas de 0,1 à 9,8 px.
//
// Les débordements de Flutter ne cassent rien, ne lèvent rien en production et
// ne se voient qu'à la bande rayée en mode debug. C'est exactement pourquoi
// ils s'accumulent : la barre de l'assistant avait débordé de 9,7 px pendant
// des semaines. Un test qui rend l'écran et refuse la moindre erreur de layout
// est le seul moyen de ne pas les laisser revenir.
//
// ── CE QUE MESURENT CES TESTS ────────────────────────────────────────────────
// Deux filets, parce qu'ils n'attrapent pas la même chose :
//
//   • `takeException() == null` à quatre largeurs et dans les trois langues :
//     attrape TOUT débordement, où qu'il soit sur la page, y compris dans du
//     code qu'on n'a pas touché. C'est le filet large.
//   • la géométrie des éléments précis (titre, badge, bouton, cadre photo) :
//     dit CE QUI dépasse et DE COMBIEN quand ça casse. Un « multiple
//     exceptions (7) » n'aide personne à 2 h du matin.
//
// 320 px est le plus petit téléphone encore en service, 360 l'Android courant,
// 393 un Pixel, 430 un grand iPhone. L'arabe est testé aussi : en RTL le
// badge passe à gauche du titre, et un texte plus long dans une Row contrainte
// déborde du côté opposé.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/features/courier/presentation/courier/courier_screen.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

const _widths = [320.0, 360.0, 393.0, 430.0];
const _locales = ['fr', 'en', 'ar'];
const _screenHeight = 900.0;

Future<AppLocalizations> pumpCourier(
  WidgetTester tester, {
  required double width,
  String locale = 'fr',
}) async {
  tester.view.physicalSize = Size(width, _screenHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CourierScreen(screenWidth: width, screenHeight: _screenHeight),
      ),
    ),
  ));
  // pumpAndSettle est exclu : l'écran lance des lectures réseau au montage,
  // qui n'aboutissent pas en test. Un pump suffit pour obtenir le layout.
  await tester.pump();

  return AppLocalizations.delegate.load(Locale(locale));
}

/// Un élément tient-il entièrement dans la largeur de l'écran ?
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
      reason: '$what dépasse à droite de ${(right - width).toStringAsFixed(1)} px');
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

  // ── Le filet large ────────────────────────────────────────────────────────
  group('aucune erreur de layout sur tout l\'écran', () {
    for (final locale in _locales) {
      for (final width in _widths) {
        testWidgets('$locale à ${width.toInt()} px', (tester) async {
          await pumpCourier(tester, width: width, locale: locale);
          // Toute erreur de layout de la page entière échoue ici, y compris
          // dans du code que ce changement n'a pas touché. C'est voulu : le
          // filet n'a d'intérêt que s'il couvre ce qu'on n'a pas regardé.
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // ── Les trois corrections, nommées ────────────────────────────────────────
  group('le titre de section', () {
    for (final width in _widths) {
      testWidgets('tient à ${width.toInt()} px', (tester) async {
        final l10n = await pumpCourier(tester, width: width);
        expectWithinScreen(tester, find.text(l10n.colisHandoverSectionTitle),
            width, 'le titre de section');
      });
    }

    testWidgets('s\'enroule au lieu d\'être coupé', (tester) async {
      // 320 px est la largeur où l'ancien en-tête débordait le plus.
      final l10n = await pumpCourier(tester, width: 320);
      final title = find.text(l10n.colisHandoverSectionTitle);
      expectWithinScreen(tester, title, 320, 'le titre de section');
      expect(tester.getSize(title).height, greaterThan(20),
          reason: 'le titre ne s\'enroule pas, il est donc coupé');
    });
  });

  group('le bouton d\'envoi', () {
    for (final width in _widths) {
      testWidgets('son contenu tient à ${width.toInt()} px', (tester) async {
        await pumpCourier(tester, width: width);

        // Le libellé et l'icône partagent une Row à l'intérieur du bouton.
        // Avec le prix estimé à côté, elle débordait de 18 à 31 px.
        expectWithinScreen(tester, find.text('Confirmer l\'envoi'), width,
            'le libellé du bouton d\'envoi');
        expectWithinScreen(tester, find.byIcon(Icons.send_rounded), width,
            'l\'icône du bouton d\'envoi');
      });
    }

    testWidgets('le libellé est réduit, jamais tronqué', (tester) async {
      await pumpCourier(tester, width: 320);
      // Un FittedBox réduit l'échelle ; une ellipse aurait donné
      // « Confirmer l'env… » sur le bouton qui engage la commande.
      final label = tester.widget<Text>(find.text('Confirmer l\'envoi'));
      expect(label.overflow, anyOf(isNull, TextOverflow.clip),
          reason: 'le libellé du bouton ne doit pas être ellipsé');
      expect(
        find.ancestor(
            of: find.text('Confirmer l\'envoi'),
            matching: find.byType(FittedBox)),
        findsWidgets,
        reason: 'sans FittedBox la Row du bouton déborde dès que le prix '
            's\'affiche',
      );
    });
  });

  group('le cadre « ajouter une photo »', () {
    for (final width in _widths) {
      testWidgets('son contenu ne dépasse pas par le bas à ${width.toInt()} px',
          (tester) async {
        await pumpCourier(tester, width: width);

        final box = find.ancestor(
          of: find.text('Ajouter une photo du colis'),
          matching: find.byType(Container),
        );
        expect(box, findsWidgets, reason: 'le cadre photo est absent');

        // Le cadre était dimensionné par la hauteur de l'écran, son contenu
        // par la largeur : le texte du bas sortait de la bordure.
        final frame = tester.getRect(box.first);
        final caption =
            tester.getRect(find.text('Appuyer pour prendre/choisir une photo'));
        expect(caption.bottom, lessThanOrEqualTo(frame.bottom + 0.5),
            reason: 'la légende dépasse du cadre de '
                '${(caption.bottom - frame.bottom).toStringAsFixed(1)} px');
      });
    }

    testWidgets('le cadre garde sa taille de référence quand ça rentre',
        (tester) async {
      // minHeight, pas height : la correction ne doit pas avoir rapetissé le
      // cadre là où il tenait déjà.
      await pumpCourier(tester, width: 320);
      final box = find
          .ancestor(
            of: find.text('Ajouter une photo du colis'),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(box).height,
          greaterThanOrEqualTo(_screenHeight * 0.14 - 0.5));
    });
  });

  group('le mode de remise', () {
    for (final width in _widths) {
      testWidgets('titres et badge dans l\'écran à ${width.toInt()} px',
          (tester) async {
        final l10n = await pumpCourier(tester, width: width);
        expectWithinScreen(tester, find.text(l10n.colisModeRecommended), width,
            'le badge Recommandé');
        expectWithinScreen(tester, find.text(l10n.colisModeCodeTitle), width,
            'le titre « Avec code »');
        expectWithinScreen(tester, find.text(l10n.colisModeNoCodeTitle), width,
            'le titre « Remise sans code »');
      });
    }

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
      // Une explication coupée à « Sans le bon code, le livreur ne peut… »
      // perd précisément ce qu'elle disait.
      for (final s in [l10n.colisModeCodeSubtitle, l10n.colisModeNoCodeSubtitle]) {
        final w = tester.widget<Text>(find.text(s));
        expect(w.maxLines, isNull, reason: 'texte tronqué : $s');
        expect(w.overflow, anyOf(isNull, TextOverflow.clip));
      }
    });
  });

  group('en arabe, le texte tient des deux côtés', () {
    for (final width in _widths) {
      testWidgets('RTL à ${width.toInt()} px', (tester) async {
        final l10n = await pumpCourier(tester, width: width, locale: 'ar');
        // En RTL, un dépassement sort par la GAUCHE : expectWithinScreen
        // vérifie les deux bords.
        expectWithinScreen(tester, find.text(l10n.colisHandoverSectionTitle),
            width, 'le titre arabe');
        expectWithinScreen(
            tester, find.text(l10n.colisModeRecommended), width, 'le badge arabe');
        expectWithinScreen(tester, find.text(l10n.colisModeCodeTitle), width,
            'le titre « avec code » arabe');
      });
    }
  });
}
