// Phone test, 29/10/2026, "Sélectionner une adresse": a saved address named
// "Ajouter une nouvelle adresse" drew "RIGHT OVERFLOWED BY 14 PIXELS" on its
// card. Every address card is laid out here at 320 px (the narrowest phones),
// in French and in Arabic (right to left), with long names and addresses.
// And the name of a new saved address is no longer pre-filled with the map
// screen's title, which is how that name got saved in the first place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:cmandili_mobile/features/checkout/data/models/delivery_address.dart';
import 'package:cmandili_mobile/features/checkout/presentation/address_selection/widgets/address_option_card.dart';
import 'package:cmandili_mobile/features/checkout/presentation/address_selection/widgets/selectable_address_card.dart';
import 'package:cmandili_mobile/features/facture/data/bill_type.dart';
import 'package:cmandili_mobile/features/facture/presentation/facture/widgets/bill_type_card.dart';
import 'package:cmandili_mobile/features/profile/data/models/address.dart';
import 'package:cmandili_mobile/features/profile/presentation/saved_addresses/widgets/add_address_dialog.dart';
import 'package:cmandili_mobile/features/profile/presentation/saved_addresses/widgets/saved_address_tile.dart';

const _longName = 'Ajouter une nouvelle adresse — Résidence Les Jasmins, bloc B, porte 12';
const _longAddress = 'M4F4+FV4, Avenue de la République, cité El Mansoura, Kairouan 3100, '
    'Tunisie, près de la pharmacie de nuit';

Future<void> _pumpAt320(WidgetTester tester, String lang, Widget child) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: Locale(lang),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(20), children: [child]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['fr', 'ar']) {
    group('320 px, $lang', () {
      testWidgets('saved address card: long name with "Par défaut" ends with …', (tester) async {
        await _pumpAt320(
          tester,
          lang,
          SelectableAddressCard(
            address: DeliveryAddress(
              id: 'a1',
              label: _longName,
              fullAddress: _longAddress,
              latitude: 35.67,
              longitude: 10.1,
              apartmentNumber: '12',
              floor: '3',
              isDefault: true,
            ),
            onTap: () {},
          ),
        );
        expect(tester.takeException(), isNull);
        final name = tester.widget<Text>(find.text(_longName));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(tester.widget<Text>(find.text(_longAddress)).maxLines, 2);
        if (lang == 'ar') {
          expect(Directionality.of(tester.element(find.text(_longName))), TextDirection.rtl);
        }
      });

      testWidgets('profile address tile, default or not', (tester) async {
        for (final isDefault in [true, false]) {
          await _pumpAt320(
            tester,
            lang,
            SavedAddressTile(
              address: Address(id: 'a$isDefault', name: _longName, fullAddress: _longAddress, isDefault: isDefault),
              onDelete: () {},
              onSetDefault: () {},
            ),
          );
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('location option card', (tester) async {
        await _pumpAt320(
          tester,
          lang,
          AddressOptionCard(
            icon: Icons.my_location,
            color: Colors.green,
            iconBackgroundAlpha: 0.1,
            title: _longName,
            subtitle: _longAddress,
            onTap: () {},
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('bill type card in a narrow grid cell', (tester) async {
        await _pumpAt320(
          tester,
          lang,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 72,
              child: BillTypeCard(type: BillType.sonede, selected: true, onTap: () {}),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('new saved address: the name', () {
    final picked = DeliveryAddress(
      id: 'p',
      // What the map picker hands back: its own title as the label.
      label: 'Ajouter une nouvelle adresse',
      fullAddress: 'M4F4+FV4, Kairouan, Tunisie',
      latitude: 35.67,
      longitude: 10.1,
    );

    Future<List<String>> open(WidgetTester tester) async {
      final saved = <String>[];
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AddAddressDialog(picked: picked, onSave: saved.add)),
      ));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('starts empty, not with the map screen title', (tester) async {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('saving without a name says so and saves nothing', (tester) async {
      final saved = await open(tester);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(saved, isEmpty);
      final l = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(find.text(l.addressLabelRequired), findsOneWidget);
    });

    testWidgets('the typed name is saved, trimmed', (tester) async {
      final saved = await open(tester);
      await tester.enterText(find.byType(TextField), '  Maison  ');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(saved, ['Maison']);
    });
  });
}
