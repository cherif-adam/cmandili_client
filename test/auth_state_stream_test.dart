import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

/// Pourquoi une connexion reussie laissait l'utilisateur sur l'ecran de
/// connexion.
///
/// `onAuthStateChange` de gotrue n'est pas un flux ordinaire : c'est un
/// `BehaviorSubject` (gotrue_client.dart:71). Deux consequences que ces tests
/// figent, parce qu'elles expliquent tout le symptome :
///
///  1. `notifyException` (gotrue_client.dart:1440) pousse une ERREUR dans ce
///     meme sujet. Changer son mot de passe revoque les jetons de
///     rafraichissement des autres sessions ; le rafraichissement qui suit
///     echoue et met le flux en erreur.
///
///  2. Un BehaviorSubject REJOUE sa derniere valeur -- erreur comprise -- a
///     chaque nouvel abonne. D'ou le fait qu'un `ref.invalidate` ne reparait
///     rien : le nouvel abonnement recoit immediatement la meme erreur.
///
/// L'ecran principal traduisait cette erreur par « pas de session » et
/// affichait l'ecran de connexion (`error: (_, __) => const AuthScreen()`).
/// La connexion suivante reussissait cote serveur, mais l'ecran ne bougeait
/// pas -- et un redemarrage suffisait a tout reparer, puisqu'il recree le
/// sujet.
void main() {
  /// Le pipeline FAUTIF : l'erreur traverse et devient l'etat courant.
  Stream<String?> broken(Stream<Object?> source) =>
      source.map((e) => e as String?);

  /// Le pipeline CORRIGE : on amorce avec l'etat reel, et une erreur du flux
  /// n'est pas lue comme une deconnexion -- elle est signalee, pas propagee.
  Stream<String?> fixed(Stream<Object?> source, String? Function() current) {
    final out = StreamController<String?>();
    out.add(current());
    source.listen(
      (e) => out.add(e as String?),
      onError: (Object _) {/* une panne de rafraichissement n'est pas une
            deconnexion : on garde le dernier etat connu */},
      onDone: out.close,
    );
    return out.stream;
  }

  test('le flux fautif transforme une erreur en etat terminal', () async {
    final subject = BehaviorSubject<Object?>();
    final seen = <Object?>[];

    broken(subject.stream).listen(seen.add, onError: seen.add);
    subject.addError(StateError('refresh token revoked'));
    await Future<void>.delayed(Duration.zero);

    expect(seen.single, isA<StateError>(),
        reason: 'l ecran lit cette erreur comme « pas de session »');

    // Et voici pourquoi invalidate ne reparait rien : un nouvel abonne recoit
    // la meme erreur, deja stockee.
    final laterSubscriber = <Object?>[];
    broken(subject.stream).listen(laterSubscriber.add, onError: laterSubscriber.add);
    await Future<void>.delayed(Duration.zero);
    expect(laterSubscriber.single, isA<StateError>(),
        reason: 'le BehaviorSubject rejoue son erreur au nouvel abonne');

    await subject.close();
  });

  test('le flux corrige survit a l erreur et voit la connexion suivante',
      () async {
    final subject = BehaviorSubject<Object?>();
    String? session; // ce que gotrue rendrait via currentUser

    final seen = <String?>[];
    final errors = <Object>[];
    fixed(subject.stream, () => session)
        .listen(seen.add, onError: errors.add);
    await Future<void>.delayed(Duration.zero);

    // 1. Le rafraichissement echoue apres le changement de mot de passe.
    subject.addError(StateError('refresh token revoked'));
    await Future<void>.delayed(Duration.zero);

    // 2. L utilisateur se reconnecte : gotrue emet signedIn.
    session = 'user-42';
    subject.add('user-42');
    await Future<void>.delayed(Duration.zero);

    expect(errors, isEmpty,
        reason: 'une erreur de flux ne doit jamais valoir deconnexion');
    expect(seen.last, 'user-42',
        reason: 'l ecran doit basculer vers l accueil apres la connexion');

    await subject.close();
  });

  test('un nouvel abonne connait l etat reel sans attendre un evenement',
      () async {
    // Le cas du `ref.invalidate` : le sujet ne contient plus rien d utile,
    // mais la session existe. Sans amorcage, l ecran resterait en chargement.
    final subject = BehaviorSubject<Object?>();
    final seen = <String?>[];

    fixed(subject.stream, () => 'user-42').listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    expect(seen.first, 'user-42');
    await subject.close();
  });
}
