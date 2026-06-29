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
  Stream<User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      return user != null ? User.fromSupabase(user) : null;
    });
  }

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

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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
}
