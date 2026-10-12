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

import 'package:flutter_test/flutter_test.dart';

import 'package:cmandili_mobile/features/courier/data/colis_repository.dart';

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

const _courierScreen = 'lib/features/courier/presentation/courier_screen.dart';
const _repoPath = 'lib/features/courier/data/colis_repository.dart';
const _cardPath = 'lib/features/orders/presentation/widgets/colis_receipt_card.dart';

void main() {
  group('la commande passe par la RPC atomique', () {
    test('plus aucune insertion directe dans orders depuis l\'écran Colis', () {
      final src = _read(_courierScreen);
      expect(src.contains("from('orders').insert"), isFalse,
          reason: 'un colis inséré directement existerait sans déclaration, '
              'et il part en broadcast aux livreurs dès sa création');
      expect(src.contains('createOrder('), isTrue);
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
      final src = _read(_courierScreen);
      expect(src.contains('_maxDeclaredValue'), isTrue);
      expect(src.contains('_validateDeclaredValue'), isTrue);
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
      final src = _read(_courierScreen);
      // Une case n'est pas un champ de formulaire : aucun validator ne la
      // couvre, il faut un contrôle explicite avant l'envoi.
      expect(src.contains('_forbiddenConfirmed'), isTrue);
      expect(src.contains('_noCodeAccepted'), isTrue);
      expect(src.contains('if (!_forbiddenConfirmed)'), isTrue,
          reason: 'sans ce garde, la case serait décorative');
    });

    test('les deux modes de remise existent et ont leur slug serveur', () {
      expect(ColisDeliveryMode.code.slug, 'code');
      expect(ColisDeliveryMode.noCode.slug, 'no_code');
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
