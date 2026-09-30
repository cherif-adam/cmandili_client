// Reproduction, sur un vrai appareil et contre le vrai Supabase, du parcours
// complet : inscription -> deconnexion -> connexion -> changement de mot de
// passe -> deconnexion -> connexion.
//
// Le test pilote le VRAI ecran d'authentification et le VRAI routeur de
// main.dart. Il n'imite rien : il tape dans les champs, appuie UNE fois sur le
// bouton, puis regarde quel ecran est affiche.
//
// Lancement (les identifiants viennent de --dart-define, jamais du depot) :
//   flutter test integration_test/auth_flow_repro_test.dart -d <device> \
//     --dart-define=REPRO_EMAIL=... --dart-define=REPRO_PASSWORD=... \
//     --dart-define=REPRO_NEW_PASSWORD=...

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:cmandili_mobile/main.dart';
import 'package:cmandili_mobile/core/config/supabase_config.dart';
import 'package:cmandili_mobile/features/auth/data/auth_repository.dart';
import 'package:cmandili_mobile/features/auth/presentation/auth_screen.dart';
import 'package:cmandili_mobile/features/home/presentation/home_screen.dart';
import 'package:cmandili_mobile/features/profile/presentation/phone_gate_screen.dart';

const _email = String.fromEnvironment('REPRO_EMAIL');
const _password = String.fromEnvironment('REPRO_PASSWORD');
const _newPassword = String.fromEnvironment('REPRO_NEW_PASSWORD');

final _stopwatch = Stopwatch()..start();

void log(String message) {
  final t = (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);
  // ignore: avoid_print
  print('[REPRO ${t.padLeft(6)}s] $message');
}

/// Quel ecran le routeur affiche, a cet instant.
String visibleScreen(WidgetTester tester) {
  if (tester.any(find.byType(HomeScreen))) return 'HomeScreen';
  if (tester.any(find.byType(PhoneGateScreen))) return 'PhoneGateScreen';
  if (tester.any(find.byType(AuthScreen))) return 'AuthScreen';
  if (tester.any(find.byType(CircularProgressIndicator))) return 'Spinner';
  return 'inconnu';
}

String sessionSummary() {
  final s = sb.Supabase.instance.client.auth.currentSession;
  if (s == null) return 'session=null';
  return 'session=ok user=${s.user.id.substring(0, 8)} expiresIn=${s.expiresIn}s';
}

/// Avance le temps par petits pas. `pumpAndSettle` est inutilisable ici :
/// l'ecran d'authentification anime son fond en boucle, il ne se stabilise
/// jamais.
Future<String> pumpUntilLeavesAuth(
  WidgetTester tester, {
  Duration budget = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(budget);
  var last = visibleScreen(tester);
  log('  ecran juste apres le tap : $last');
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    final now = visibleScreen(tester);
    if (now != last) {
      log('  ecran -> $now   (${sessionSummary()})');
      last = now;
      if (now == 'HomeScreen' || now == 'PhoneGateScreen') return now;
    }
  }
  return last;
}

Future<void> tapSubmit(WidgetTester tester) async {
  final button = find.byKey(const Key('auth_submit'));
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 200));
  final enabled = tester.widget<ElevatedButton>(button).onPressed != null;
  log('  bouton actif avant le tap : $enabled');
  await tester.tap(button);
  log('  TAP sur le bouton (UNE seule fois)');
  await tester.pump();
}

Future<void> fillField(WidgetTester tester, String key, String value) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, value);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours complet inscription / connexion / mot de passe',
      (tester) async {
    expect(_email.isNotEmpty, isTrue, reason: 'REPRO_EMAIL manquant');
    expect(_password.isNotEmpty, isTrue, reason: 'REPRO_PASSWORD manquant');

    await dotenv.load(fileName: '.env');
    await sb.Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    final client = sb.Supabase.instance.client;

    // Journal brut de TOUT ce que gotrue emet, erreurs comprises.
    final sub = client.auth.onAuthStateChange.listen(
      (state) => log('    << evenement gotrue : ${state.event} '
          'session=${state.session != null ? "ok" : "null"}'),
      onError: (Object e) => log('    << ERREUR sur le flux gotrue : $e'),
    );
    addTearDown(sub.cancel);

    // Point de depart propre : personne ne doit etre connecte.
    try {
      await client.auth.signOut();
    } catch (_) {}
    log('etat de depart : ${sessionSummary()}');

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(seconds: 2));
    log('ecran au demarrage : ${visibleScreen(tester)}');

    // -- ETAPE 1 - INSCRIPTION ------------------------------------------------
    log('');
    log('ETAPE 1 - INSCRIPTION ($_email)');
    await tester.tap(find.byKey(const Key('auth_tab_signup')));
    await tester.pump(const Duration(milliseconds: 500));
    await fillField(tester, 'auth_name', 'QA Amana');
    await fillField(tester, 'auth_email', _email);
    await fillField(tester, 'auth_password', _password);
    await tapSubmit(tester);
    final afterSignUp = await pumpUntilLeavesAuth(tester);
    log('RESULTAT inscription : ecran=$afterSignUp  ${sessionSummary()}');

    // -- ETAPE 2 - DECONNEXION ------------------------------------------------
    log('');
    log('ETAPE 2 - DECONNEXION');
    await client.auth.signOut();
    await tester.pump(const Duration(seconds: 2));
    log('RESULTAT deconnexion : ecran=${visibleScreen(tester)}  ${sessionSummary()}');

    // -- ETAPE 3 - CONNEXION --------------------------------------------------
    log('');
    log('ETAPE 3 - CONNEXION (mot de passe correct)');
    await tester.tap(find.byKey(const Key('auth_tab_signin')));
    await tester.pump(const Duration(milliseconds: 500));
    await fillField(tester, 'auth_email', _email);
    await fillField(tester, 'auth_password', _password);
    await tapSubmit(tester);
    final afterSignIn = await pumpUntilLeavesAuth(tester);
    log('RESULTAT connexion : ecran=$afterSignIn  ${sessionSummary()}');

    // -- ETAPE 4 - CHANGEMENT DE MOT DE PASSE ---------------------------------
    log('');
    log('ETAPE 4 - CHANGEMENT DE MOT DE PASSE');
    final repo = AuthRepository();
    final err = await repo.changePassword(
      currentPassword: _password,
      newPassword: _newPassword,
    );
    log('changePassword -> ${err ?? "succes"}');
    await tester.pump(const Duration(seconds: 2));
    log('RESULTAT changement : ecran=${visibleScreen(tester)}  ${sessionSummary()}');

    // -- ETAPE 5 - DECONNEXION ------------------------------------------------
    log('');
    log('ETAPE 5 - DECONNEXION apres changement');
    await client.auth.signOut();
    await tester.pump(const Duration(seconds: 2));
    log('RESULTAT deconnexion : ecran=${visibleScreen(tester)}  ${sessionSummary()}');

    // -- ETAPE 6 - CONNEXION AVEC LE NOUVEAU MOT DE PASSE ---------------------
    log('');
    log('ETAPE 6 - CONNEXION avec le NOUVEAU mot de passe');
    await tester.tap(find.byKey(const Key('auth_tab_signin')));
    await tester.pump(const Duration(milliseconds: 500));
    await fillField(tester, 'auth_email', _email);
    await fillField(tester, 'auth_password', _newPassword);
    await tapSubmit(tester);
    final afterSignIn2 = await pumpUntilLeavesAuth(tester);
    log('RESULTAT connexion finale : ecran=$afterSignIn2  ${sessionSummary()}');

    log('');
    log('=========== RESUME ===========');
    log('inscription         -> $afterSignUp');
    log('connexion           -> $afterSignIn');
    log('connexion (nouveau) -> $afterSignIn2');
    log('==============================');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
