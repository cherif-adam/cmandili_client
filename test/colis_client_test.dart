// Bon de prise en charge Colis — garanties côté expéditeur.
//
// Comme côté livreur, deux familles : des tests de SOURCE pour les
// interdictions (une propriété d'un fichier entier ne se prouve pas en
// exerçant un appel), et des tests de comportement pour le reste.
//
// Hors de portée ici, et c'est normal : l'immuabilité, l'invisibilité du code
// pour le livreur, le plafond appliqué côté serveur et la fenêtre de litige
// vérifiée en base. Ce sont des garanties de PostgreSQL ; elles se testent
// avec le harnais SQL, pas depuis Flutter. Ce fichier vérifie que le client
// demande les bonnes choses et refuse les mauvaises avant d'envoyer.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cmandili_mobile/features/courier/data/colis_repository.dart';
import 'package:cmandili_mobile/features/orders/presentation/widgets/colis_receipt_card.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

/// Source d'un fichier, COMMENTAIRES RETIRÉS. Sans ce dépouillage une
/// assertion d'interdiction tombe sur le commentaire qui explique la règle et
/// ne prouve rien.
String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: 'fichier introuvable : $path');
  return f
      .readAsLinesSync()
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');
}

// L'écran Colis est découpé en deux fichiers : l'UI (écran) et ce qu'elle
// fait (contrôleur). Les règles du bon de prise en charge vivent dans le
// contrôleur ; les textes affichés restent dans l'écran.
const _courierScreen =
    'lib/features/courier/presentation/courier/courier_screen.dart';
const _courierController =
    'lib/features/courier/presentation/courier/courier_controller.dart';
const _modeSelector =
    'lib/features/courier/presentation/courier/widgets/delivery_mode_selector.dart';
const _repoPath = 'lib/features/courier/data/colis_repository.dart';
const _cardPath = 'lib/features/orders/presentation/widgets/colis_receipt_card.dart';

/// Dépôt sans réseau : la carte ne doit dépendre que de ce qu'on lui donne.
class _FakeRepo extends ColisRepository {
  _FakeRepo({required this.receipt, this.code});

  final Map<String, dynamic>? receipt;
  final String? code;

  @override
  Future<Map<String, dynamic>?> loadReceipt(String orderId) async => receipt;

  @override
  Future<String?> loadDeliveryCode(String orderId) async => code;

  // Aucune photo : une image réseau dans un test n'apprend rien et fait
  // dépendre le test d'un décodeur.
  @override
  Future<String?> signedProofUrl(String path, {int secondsValid = 3600}) async =>
      null;
}

/// La carte telle que l'app la monte : MaterialApp + délégués de langue.
Future<void> pumpCard(
  WidgetTester tester, {
  required Map<String, dynamic>? receipt,
  String? code,
  DateTime? deliveredAt,
  String locale = 'fr',
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ColisReceiptCard(
          orderId: 'o-1',
          deliveredAt: deliveredAt,
          repository: _FakeRepo(receipt: receipt, code: code),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _receiptWithCode() => {
      'delivery_mode': 'code',
      'delivery_at': null,
      'description': 'Documents',
      'declared_value': 120,
    };

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // ColisRepository() résout Supabase.instance.client dans son constructeur,
    // y compris pour le faux dépôt : sans initialisation il lèverait.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      debug: false,
    );
  });

  group('la commande passe par la RPC atomique', () {
    test('plus aucune insertion directe dans orders depuis l\'écran Colis', () {
      for (final path in [_courierScreen, _courierController]) {
        expect(_read(path).contains("from('orders').insert"), isFalse,
            reason: 'un colis inséré directement existerait sans déclaration, '
                'et il part en broadcast aux livreurs dès sa création '
                '($path)');
      }
      expect(_read(_courierController).contains('createOrder('), isTrue);
    });

    test('le dépôt appelle bien create_colis_order', () {
      expect(_read(_repoPath).contains('create_colis_order'), isTrue);
    });
  });

  group('plafond de valeur déclarée', () {
    test('le plafond vient de la base, pas du code', () {
      final src = _read(_repoPath);
      expect(src.contains('platform_settings'), isTrue);
      expect(src.contains('colis_max_declared_value'), isTrue);
    });

    test('la valeur de repli vaut 300 TND', () {
      // Repli d'affichage seulement : le serveur revalide de toute façon.
      expect(kColisFallbackMaxValue, 300);
    });

    test('l\'écran valide contre le plafond chargé, pas une constante', () {
      final src = _read(_courierController);
      expect(src.contains('state.maxDeclaredValue'), isTrue);
      expect(src.contains('validateDeclaredValue('), isTrue);
      // Le validator vit dans le contrôleur : l'écran doit encore s'en servir.
      expect(
          _read(_courierScreen).contains('controller.validateDeclaredValue('),
          isTrue);
    });
  });

  group('articles interdits et mode de remise', () {
    test('la liste des interdits couvre les quatre familles', () {
      final labels = kColisForbiddenItems.map((e) => e.$2.toLowerCase()).join(' ');
      for (final must in ['argent', 'bijoux', 'documents', 'illégaux']) {
        expect(labels.contains(must), isTrue, reason: '$must manquant');
      }
    });

    test('les deux cases bloquent l\'envoi tant qu\'elles ne sont pas cochées',
        () {
      final src = _read(_courierController);
      // Une case n'est pas un champ de formulaire : aucun validator ne la
      // couvre, il faut un contrôle explicite avant l'envoi.
      expect(src.contains('forbiddenConfirmed'), isTrue);
      expect(src.contains('noCodeAccepted'), isTrue);
      expect(src.contains('if (!state.forbiddenConfirmed)'), isTrue,
          reason: 'sans ce garde, la case serait décorative');
      // Le garde vit dans le contrôleur : l'écran doit le consulter avant
      // d'envoyer.
      expect(_read(_courierScreen).contains('controller.blocker()'), isTrue,
          reason: 'sans cet appel, le garde ne bloquerait rien');
    });

    test('les deux modes de remise existent et ont leur slug serveur', () {
      expect(ColisDeliveryMode.code.slug, 'code');
      expect(ColisDeliveryMode.noCode.slug, 'no_code');
    });
  });

  // ── Ce que l'expéditeur LIT avant de choisir ─────────────────────────────
  //
  // Le choix du mode de remise est le seul endroit où l'expéditeur décide de
  // sa propre protection. Un libellé qui ne dit pas ce que le code sert à
  // empêcher le laisse choisir au hasard, et c'est le mode SANS code qu'il
  // regrettera. Ces tests figent donc le sens des textes, pas leur jolie
  // tournure : un remaniement qui en retire la raison d'être les casse.

  group('les textes du mode de remise', () {
    test('le mode recommandé est aussi celui par défaut', () {
      final src = _read(_courierController);
      expect(
        src.contains('this.deliveryMode = ColisDeliveryMode.code'),
        isTrue,
        reason: 'le badge « Recommandé » doit porter sur le mode pré-coché',
      );
      // Les options vivent dans leur propre widget depuis le découpage de
      // l'écran en un widget par fichier.
      final selector = _read(_modeSelector);
      expect(selector.contains('badge: l10n.colisModeRecommended'), isTrue);
      expect(selector.contains('icon: Icons.lock_outline'), isTrue,
          reason: 'le cadenas signale le mode protégé');
    });

    test('plus aucun libellé de mode en dur dans l\'écran', () {
      // Sinon l'anglais et l'arabe afficheraient du français.
      final screen = _read(_courierScreen);
      final controller = _read(_courierController);
      final selector = _read(_modeSelector);
      for (final literal in [
        "'Avec code'",
        "'Remise sans code'",
        "'Remise au destinataire'",
      ]) {
        expect(screen.contains(literal), isFalse,
            reason: '$literal est resté en dur dans l\'écran');
        expect(controller.contains(literal), isFalse,
            reason: '$literal est resté en dur dans le contrôleur');
        expect(selector.contains(literal), isFalse,
            reason: '$literal est resté en dur dans le sélecteur');
      }
      expect(screen.contains('l10n.colisHandoverSectionTitle'), isTrue);
      expect(selector.contains('l10n.colisModeCodeSubtitle'), isTrue);
      expect(selector.contains('l10n.colisModeNoCodeSubtitle'), isTrue);
    });

    test('le titre de section pose une question à l\'expéditeur', () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(fr.colisHandoverSectionTitle,
          'Comment le livreur remet votre colis ?');
    });

    test('« Avec code » explique ce que le code EMPÊCHE', () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      final s = fr.colisModeCodeSubtitle;
      expect(fr.colisModeCodeTitle, 'Avec code');
      expect(fr.colisModeRecommended, 'Recommandé');
      // Les quatre idées qui font la décision : c'est le plus sûr, il y a un
      // code à 4 chiffres, il faut l'envoyer au destinataire, et sans lui la
      // livraison ne peut pas se terminer.
      expect(s, contains('plus sûr'));
      expect(s, contains('4 chiffres'));
      expect(s, contains('Envoyez-le'));
      expect(s, contains('ne peut pas terminer la livraison'));
    });

    test('« Remise sans code » dit à qui elle sert et qu\'elle est moins sûre',
        () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      final s = fr.colisModeNoCodeSubtitle;
      expect(fr.colisModeNoCodeTitle, 'Remise sans code');
      expect(s, contains('pas de téléphone'));
      expect(s, contains('photo'));
      expect(s, contains('position'));
      expect(s, contains('moins sûr'),
          reason: 'sans cet avertissement le choix paraît équivalent',
      );
    });

    test('les trois langues ont tous les textes, aucun vide', () async {
      for (final code in ['fr', 'en', 'ar']) {
        final l = await AppLocalizations.delegate.load(Locale(code));
        for (final entry in {
          'colisHandoverSectionTitle': l.colisHandoverSectionTitle,
          'colisModeRecommended': l.colisModeRecommended,
          'colisModeCodeTitle': l.colisModeCodeTitle,
          'colisModeCodeSubtitle': l.colisModeCodeSubtitle,
          'colisModeNoCodeTitle': l.colisModeNoCodeTitle,
          'colisModeNoCodeSubtitle': l.colisModeNoCodeSubtitle,
          'colisCodeExplain': l.colisCodeExplain,
          'colisShareSubject': l.colisShareSubject,
        }.entries) {
          expect(entry.value.trim(), isNotEmpty,
              reason: '$code : ${entry.key} est vide');
        }
        // Les deux textes à trou doivent réellement placer le code.
        expect(l.colisCodeHeadline('7203'), contains('7203'),
            reason: '$code : le code n\'apparaît pas dans l\'en-tête');
        expect(l.colisShareMessage('7203'), contains('7203'),
            reason: '$code : le code n\'apparaît pas dans le partage');
      }
    });

    test('l\'anglais et l\'arabe ne sont pas restés en français', () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      for (final code in ['en', 'ar']) {
        final l = await AppLocalizations.delegate.load(Locale(code));
        expect(l.colisModeCodeSubtitle, isNot(fr.colisModeCodeSubtitle),
            reason: '$code reprend le texte français');
        expect(l.colisModeNoCodeSubtitle, isNot(fr.colisModeNoCodeSubtitle),
            reason: '$code reprend le texte français');
      }
    });
  });

  group('le code, tel que l\'expéditeur le voit', () {
    testWidgets('l\'en-tête porte le code et la consigne le précède',
        (tester) async {
      await pumpCard(tester, receipt: _receiptWithCode(), code: '7203');

      // L'en-tête annoncé : « Votre code de remise : 7203 ».
      expect(find.text('Votre code de remise : 7203'), findsOneWidget);
      expect(
        find.text(
            'Envoyez ce code au destinataire. Il le donnera au livreur quand '
            'il recevra le colis.'),
        findsOneWidget,
      );
      // Le code en gros chiffres reste là, pour qu'il soit lisible d'un coup.
      expect(find.text('7203'), findsOneWidget);
    });

    testWidgets('la consigne arrive AVANT le bouton Partager', (tester) async {
      await pumpCard(tester, receipt: _receiptWithCode(), code: '7203');

      final consigne = tester
          .getTopLeft(find.text(
              'Envoyez ce code au destinataire. Il le donnera au livreur '
              'quand il recevra le colis.'))
          .dy;
      final partage =
          tester.getTopLeft(find.byIcon(Icons.share_rounded)).dy;
      expect(consigne, lessThan(partage),
          reason: 'lue après coup, la consigne ne sert plus à rien');
    });

    testWidgets('l\'ancienne légende sous les boutons a disparu',
        (tester) async {
      await pumpCard(tester, receipt: _receiptWithCode(), code: '7203');
      // Elle disait la même chose que la nouvelle consigne, une ligne plus bas.
      expect(find.textContaining('Transmettez-le au destinataire'), findsNothing);
      expect(find.text('Code de remise'), findsNothing);
    });

    testWidgets('rien du tout en mode sans code', (tester) async {
      await pumpCard(
        tester,
        receipt: {
          'delivery_mode': 'no_code',
          'delivery_at': null,
          'receiver_label': 'Gardien de l\'école',
          'description': 'Cahiers',
        },
      );
      expect(find.textContaining('code de remise'), findsNothing);
      // Mais le bon reste affiché, avec la personne désignée.
      expect(find.text('Gardien de l\'école'), findsOneWidget);
    });

    testWidgets('le code disparaît une fois le colis remis', (tester) async {
      await pumpCard(
        tester,
        receipt: {
          'delivery_mode': 'code',
          'delivery_at': '2026-10-15T18:00:00Z',
          'description': 'Documents',
        },
        code: '7203',
      );
      expect(find.textContaining('Votre code de remise'), findsNothing);
      expect(find.text('7203'), findsNothing);
    });

    test('le message de partage s\'adresse au destinataire', () async {
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      final msg = fr.colisShareMessage('7203');
      // Il part au destinataire : il le salue et lui dit quoi faire. L'ancien
      // texte (« Votre colis arrive bientôt ») parlait à l'expéditeur.
      expect(msg, startsWith('Bonjour'));
      expect(msg, contains('Donnez ce code au livreur'));
      expect(msg, contains('7203'));
      expect(msg, isNot(contains('Votre colis Amana arrive')));
    });

    test('la carte ne construit plus le partage en dur', () {
      final src = _read(_cardPath);
      expect(src.contains('l10n.colisShareMessage'), isTrue);
      expect(src.contains("'Votre colis Amana arrive"), isFalse);
    });
  });

  group('fenêtre de litige de 24 h', () {
    test('ouverte juste après la livraison', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      expect(
        ColisRepository.canDispute(now.subtract(const Duration(minutes: 1)),
            now: now),
        isTrue,
      );
    });

    test('toujours ouverte à 23 h 59', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      expect(
        ColisRepository.canDispute(
            now.subtract(const Duration(hours: 23, minutes: 59)),
            now: now),
        isTrue,
      );
    });

    test('fermée à 24 h pile et au-delà', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      expect(
        ColisRepository.canDispute(now.subtract(const Duration(hours: 24)),
            now: now),
        isFalse,
      );
      expect(
        ColisRepository.canDispute(now.subtract(const Duration(hours: 30)),
            now: now),
        isFalse,
      );
    });

    test('fermée tant que la commande n\'est pas livrée', () {
      expect(ColisRepository.canDispute(null), isFalse);
    });

    test('indépendante du fuseau : une heure locale est ramenée en UTC', () {
      final now = DateTime.utc(2026, 10, 12, 12);
      // 23 h avant, exprimé en heure locale Tunisie (UTC+1).
      final local = now
          .subtract(const Duration(hours: 23))
          .add(const Duration(hours: 1))
          .toLocal();
      expect(ColisRepository.canDispute(local, now: now), isTrue);
    });
  });

  group('preuves et code', () {
    test('les photos sont relues par URL signée, jamais publique', () {
      final src = _read(_repoPath);
      expect(src.contains('createSignedUrl'), isTrue);
      expect(src.contains('getPublicUrl'), isFalse,
          reason: 'colis-proofs est privé');
    });

    test('le code est lu dans la table réservée à l\'expéditeur', () {
      expect(_read(_repoPath).contains('colis_delivery_codes'), isTrue);
    });

    test('la carte n\'affiche le code que tant que le colis n\'est pas remis',
        () {
      final src = _read(_cardPath);
      expect(src.contains("r['delivery_at'] == null"), isTrue,
          reason: 'après la remise le code n\'a plus de raison d\'être montré');
    });

    test('la carte propose le partage du code', () {
      final src = _read(_cardPath);
      expect(src.contains('Share.share'), isTrue);
    });
  });

  group('compatibilité ascendante', () {
    test('un reçu absent ne casse rien', () {
      // loadReceipt avale l'erreur et renvoie null quand la table n'existe
      // pas encore : un build neuf doit rester utilisable sur une base pas
      // à jour.
      final src = _read(_repoPath);
      expect(src.contains('catch (_) {'), isTrue);
    });

    test('la carte ne rend rien sans reçu', () {
      expect(
        _read(_cardPath).contains('_receipt == null) return const SizedBox.shrink()'),
        isTrue,
      );
    });
  });
}
