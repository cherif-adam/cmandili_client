import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'package:cmandili_mobile/features/account_deletion/data/models/deletion_blocker.dart';
import 'package:cmandili_mobile/features/account_deletion/presentation/delete_account/delete_account_controller.dart';
import 'package:cmandili_mobile/features/account_deletion/presentation/delete_account/widgets/blocker_text.dart';
import 'package:cmandili_mobile/features/account_deletion/presentation/delete_account/widgets/deletion_blockers_card.dart';
import 'package:cmandili_mobile/features/account_deletion/presentation/delete_account/widgets/deletion_confirm_form.dart';

/// « Supprimer mon compte » : ce que l'app décide elle-même. La suppression
/// et la vérification des blocages sont côté serveur (testées par
/// supabase/tests/account_deletion_test.sql) ; ici, la lecture de la réponse,
/// le mot à taper, les messages de blocage et le formulaire.
void main() {
  group('DeletionBlocker.listFrom', () {
    test('lit codes, nombres et montants', () {
      final list = DeletionBlocker.listFrom([
        {'code': 'shop_active_orders', 'count': 2},
        {'code': 'wallet_balance', 'amount': 12.5},
        {'code': 'admin_account'},
      ]);
      expect(list.map((b) => b.code), ['shop_active_orders', 'wallet_balance', 'admin_account']);
      expect(list[0].count, 2);
      expect(list[1].amount, 12.5);
      expect(list[2].count, isNull);
    });

    test('une réponse inattendue donne une liste vide, sans planter', () {
      expect(DeletionBlocker.listFrom(null), isEmpty);
      expect(DeletionBlocker.listFrom('x'), isEmpty);
      expect(DeletionBlocker.listFrom([1, 'a']), isEmpty);
    });
  });

  group('mot de confirmation', () {
    test('accepte le mot, sans tenir compte des espaces ni de la casse', () {
      expect(DeleteAccountController.wordMatches(' supprimer ', 'SUPPRIMER'), isTrue);
      expect(DeleteAccountController.wordMatches('حذف', 'حذف'), isTrue);
    });

    test('refuse tout autre texte', () {
      expect(DeleteAccountController.wordMatches('SUPPRIME', 'SUPPRIMER'), isFalse);
      expect(DeleteAccountController.wordMatches('', 'SUPPRIMER'), isFalse);
      expect(DeleteAccountController.wordMatches(null, 'SUPPRIMER'), isFalse);
    });
  });

  group('messages de blocage', () {
    late AppLocalizations fr;
    setUpAll(() async => fr = await AppLocalizations.delegate.load(const Locale('fr')));

    test('chaque code connu a son propre message', () {
      const codes = [
        'admin_account', 'active_orders', 'open_disputes', 'driver_active_orders',
        'driver_open_disputes', 'driver_payouts_pending', 'shop_active_orders',
        'wallet_balance', 'settlements_pending',
      ];
      for (final code in codes) {
        expect(
          blockerText(fr, DeletionBlocker(code: code, count: 1, amount: 1)),
          isNot(fr.deleteAccountBlockerUnknown),
          reason: code,
        );
      }
    });

    test('le solde est affiché au millime et dit quoi faire', () {
      final text = blockerText(fr, const DeletionBlocker(code: 'wallet_balance', amount: 12.5));
      expect(text, contains('12.500 TND'));
      expect(text, contains("Contactez l'équipe Amana"));
    });

    test('un code inconnu bloque quand même, avec un message générique', () {
      expect(blockerText(fr, const DeletionBlocker(code: 'nouveau_code')), fr.deleteAccountBlockerUnknown);
    });
  });

  group('écran', () {
    Widget host(Widget child) => MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    testWidgets('les blocages s’affichent avec l’accès au support', (tester) async {
      await tester.pumpWidget(host(const DeletionBlockersCard(blockers: [
        DeletionBlocker(code: 'active_orders', count: 3),
        DeletionBlocker(code: 'open_disputes', count: 1),
      ])));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vous avez 3 commande(s) en cours'), findsOneWidget);
      expect(find.textContaining('Un litige colis est encore ouvert'), findsOneWidget);
      expect(find.text("Contacter l'équipe Amana"), findsOneWidget);
    });

    testWidgets('un mauvais mot est refusé avant tout appel', (tester) async {
      final formKey = GlobalKey<FormState>();
      final word = TextEditingController(text: 'supprime');
      final password = TextEditingController(text: 'secret');
      var submitted = 0;
      await tester.pumpWidget(host(DeletionConfirmForm(
        formKey: formKey,
        wordController: word,
        passwordController: password,
        method: 'password',
        showPassword: false,
        busy: false,
        errorText: null,
        onTogglePassword: () {},
        onSubmit: () {
          if (formKey.currentState!.validate()) submitted++;
        },
      )));
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      await tester.pumpAndSettle();
      expect(find.text('Tapez exactement SUPPRIMER'), findsOneWidget);
      expect(submitted, 0);

      word.text = 'SUPPRIMER';
      await tester.tap(find.text('Supprimer définitivement mon compte'));
      await tester.pumpAndSettle();
      expect(submitted, 1);
    });

    testWidgets('compte Apple : pas de mot de passe, reconnexion Apple annoncée', (tester) async {
      await tester.pumpWidget(host(DeletionConfirmForm(
        formKey: GlobalKey<FormState>(),
        wordController: TextEditingController(),
        passwordController: TextEditingController(),
        method: 'apple',
        showPassword: false,
        busy: false,
        errorText: null,
        onTogglePassword: () {},
        onSubmit: () {},
      )));
      expect(find.textContaining('reconnecter avec Apple'), findsOneWidget);
      expect(find.text('Mot de passe'), findsNothing);
    });

    testWidgets('sans méthode de confirmation, le bouton est désactivé', (tester) async {
      await tester.pumpWidget(host(DeletionConfirmForm(
        formKey: GlobalKey<FormState>(),
        wordController: TextEditingController(),
        passwordController: TextEditingController(),
        method: null,
        showPassword: false,
        busy: false,
        errorText: null,
        onTogglePassword: () {},
        onSubmit: () => fail('ne doit pas être appelé'),
      )));
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Contactez l\'équipe Amana'), findsOneWidget);
    });
  });
}
