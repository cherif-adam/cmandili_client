import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Simple User class to replace Firebase User
class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String role;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.role = 'client',
  });

  factory User.fromSupabase(supabase.User user) {
    return User(
      uid: user.id,
      email: user.email,
      displayName: user.userMetadata?['full_name'] as String? ?? user.userMetadata?['name'] as String?,
      photoURL: user.userMetadata?['avatar_url'] as String? ?? user.userMetadata?['picture'] as String?,
      role: user.appMetadata['role'] as String? ?? 'client',
    );
  }
}

class AuthRepository {
  final _supabase = supabase.Supabase.instance.client;
  final _googleSignIn = GoogleSignIn(
    serverClientId: '785469526658-r0cl6q3cgourm68om0oo3pk4077auo4r.apps.googleusercontent.com',
  );
  
  // Get current user
  User? get currentUser {
    final user = _supabase.auth.currentUser;
    return user != null ? User.fromSupabase(user) : null;
  }

  // Auth state changes stream
  /// L'etat de connexion, tel que l'ecran principal doit le lire.
  ///
  /// Deux protections, et chacune corrige un symptome observe.
  ///
  /// AMORCAGE. On emet d'abord la session REELLE, sans attendre un evenement.
  /// `onAuthStateChange` est un BehaviorSubject : un nouvel abonne recoit sa
  /// derniere valeur, qui peut n'avoir aucun rapport avec l'etat courant --
  /// ou ne rien contenir du tout.
  ///
  /// ERREURS NEUTRALISEES. `notifyException` pousse les ERREURS dans ce meme
  /// sujet : un rafraichissement de jeton qui echoue met le flux en erreur.
  /// Changer son mot de passe revoque justement les jetons des autres
  /// sessions, donc le rafraichissement suivant echouait. L'ecran principal
  /// traduisait cette erreur par « pas de session » et affichait l'ecran de
  /// connexion -- la connexion suivante reussissait cote serveur, mais rien
  /// ne bougeait, et seul un redemarrage reparait, puisqu'il recree le sujet.
  /// Un `ref.invalidate` n'y pouvait rien : le sujet REJOUE son erreur au
  /// nouvel abonne.
  ///
  /// Une panne de rafraichissement n'est pas une deconnexion. Elle est
  /// signalee, jamais propagee ; le dernier etat connu tient.
  /// Voir test/auth_state_stream_test.dart.
  Stream<User?> get authStateChanges {
    User? fromSession(supabase.Session? session) {
      final user = session?.user;
      return user != null ? User.fromSupabase(user) : null;
    }

    final out = StreamController<User?>();
    out.add(fromSession(_supabase.auth.currentSession));

    final sub = _supabase.auth.onAuthStateChange.listen(
      (data) => out.add(fromSession(data.session)),
      onError: (Object e) {
        debugPrint('authStateChanges: erreur ignoree ($e)');
      },
    );
    out.onCancel = sub.cancel;
    return out.stream;
  }

  /// Whether a usable session exists right now. After signUp this is false
  /// when the project requires email confirmation: the account is created but
  /// the user cannot enter until they click the link in the email.
  bool get hasSession => _supabase.auth.currentSession != null;

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    final user = response.user;
    if (user == null) throw 'Sign in failed';
    
    return User.fromSupabase(user);
  }

  // Sign up with email and password
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
    
    final user = response.user;
    if (user == null) throw 'Sign up failed';
    
    return User.fromSupabase(user);
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Google sign in failed';
      
      return User.fromSupabase(user);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  // Sign in with Apple — uses a nonce to bind the Apple idToken to the Supabase session.
  Future<User?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'Apple sign in failed: no identity token';
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final user = response.user;
      if (user == null) throw 'Apple sign in failed';

      // Apple only shares name on first sign-in; persist it to profile if present.
      final fullName = [
        credential.givenName ?? '',
        credential.familyName ?? '',
      ].where((s) => s.isNotEmpty).join(' ').trim();
      if (fullName.isNotEmpty) {
        await _supabase.auth.updateUser(
          supabase.UserAttributes(data: {'full_name': fullName}),
        );
      }

      return User.fromSupabase(user);
    } catch (e) {
      debugPrint('Apple Sign In Error: $e');
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // Sign out. The Supabase session is what the app routes on, so it must end
  // even if the Google sign-out fails (e.g. the user never used Google).
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('signOut: Google sign-out failed ($e), continuing');
    }
    await _supabase.auth.signOut();
  }

  // ── Password reset (OTP flow) ──────────────────────────────────────────────

  /// Step 1 — Sends a 6-digit recovery code to [email].
  /// Supabase's "Reset Password" email template must be set to OTP mode
  /// (use {{ .Token }} instead of {{ .ConfirmationURL }} — see SUPABASE SETUP).
  Future<void> sendPasswordResetOtp(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Step 2 — Verifies the 6-digit [token] the user received by email and
  /// establishes a short-lived recovery session.  Must be called before
  /// [updatePassword].
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: supabase.OtpType.recovery,
    );
  }

  /// Step 3 — Replaces the current user's password.  Only valid after a
  /// successful [verifyPasswordResetOtp] call.
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      supabase.UserAttributes(password: newPassword),
    );
  }

  // ── Changement de mot de passe, utilisateur connecte ──────────────────────

  /// Change le mot de passe d'un utilisateur DEJA connecte.
  ///
  /// Renvoie `null` en cas de succes, sinon un CODE d'erreur que l'ecran
  /// traduit : le depot ne connait pas la langue du client, et les messages
  /// que renvoie Supabase sont en anglais.
  ///
  ///   wrong_current   le mot de passe actuel est faux
  ///   same_as_old     le nouveau est identique a l'ancien
  ///   too_short       refuse par le serveur (longueur, politique)
  ///   reauth_needed   « Secure password change » est actif cote Supabase :
  ///                   il faut un code de reauthentification recent
  ///   no_session      plus de session, ou compte sans email
  ///   failed          tout le reste
  ///
  /// Le mot de passe actuel est verifie en se reconnectant avec lui. C'est la
  /// seule verification que Supabase offre : il n'existe pas d'API « ce mot de
  /// passe est-il le bon ». signInWithPassword rafraichit la session en place,
  /// l'utilisateur n'est donc pas deconnecte de cet appareil -- mais il FAUT
  /// verifier avant, sinon un telephone laisse deverrouille suffirait a
  /// changer le mot de passe du compte.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) return 'no_session';

    if (currentPassword == newPassword) return 'same_as_old';

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on supabase.AuthException catch (e) {
      debugPrint('changePassword: reauth refusee (${e.message})');
      return 'wrong_current';
    } catch (e) {
      debugPrint('changePassword: reauth impossible ($e)');
      return 'failed';
    }

    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
      return null;
    } on supabase.AuthException catch (e) {
      final m = e.message.toLowerCase();
      // Supabase ne renvoie pas de code stable ici : on lit le message, et on
      // retombe sur 'failed' plutot que d'afficher de l'anglais au client.
      if (m.contains('reauthentication')) return 'reauth_needed';
      if (m.contains('should be different') ||
          m.contains('same as the old')) {
        return 'same_as_old';
      }
      if (m.contains('at least') || m.contains('password')) return 'too_short';
      debugPrint('changePassword: refus serveur (${e.message})');
      return 'failed';
    } catch (e) {
      debugPrint('changePassword: echec ($e)');
      return 'failed';
    }
  }

  /// Deconnecte les AUTRES appareils, en gardant celui-ci connecte.
  ///
  /// Propose apres un changement de mot de passe : si quelqu'un d'autre avait
  /// une session ouverte, la changer ne la ferme pas toute seule.
  Future<bool> signOutOtherDevices() async {
    try {
      await _supabase.auth.signOut(scope: supabase.SignOutScope.others);
      return true;
    } catch (e) {
      debugPrint('signOutOtherDevices: $e');
      return false;
    }
  }
}
