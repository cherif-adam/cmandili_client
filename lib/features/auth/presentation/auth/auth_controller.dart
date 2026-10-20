import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../providers/auth_provider.dart';

/// One controller per sign-in screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final authScreenControllerProvider = NotifierProvider.autoDispose
    .family<AuthScreenController, AuthScreenState, Object>(AuthScreenController.new);

@immutable
class AuthScreenState {
  const AuthScreenState({this.isLoading = false, this.obscurePassword = true});

  final bool isLoading;
  final bool obscurePassword;
}

/// What an e-mail sign-in / sign-up led to (errors throw instead).
enum EmailAuthOutcome {
  /// A session is open: the app can show Home.
  signedIn,

  /// Account created but no session: the project requires the user to
  /// confirm their e-mail first.
  needsEmailConfirmation,
}

class AuthScreenController extends AutoDisposeFamilyNotifier<AuthScreenState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  AuthScreenState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const AuthScreenState();
  }

  void _setLoading(bool value) {
    if (_disposed) return;
    state = AuthScreenState(isLoading: value, obscurePassword: state.obscurePassword);
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void toggleObscurePassword() => state = AuthScreenState(
        isLoading: state.isLoading,
        obscurePassword: !state.obscurePassword,
      );

  /// Signs in ([isSignIn]) or creates the account with [name]. E-mail and
  /// name are trimmed, the password is not. Errors throw: pass them to
  /// [friendlyAuthErrorMessage].
  Future<EmailAuthOutcome> submitEmail({
    required bool isSignIn,
    required String email,
    required String password,
    required String name,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
    _setLoading(true);
    try {
      if (isSignIn) {
        await authRepo
            .signInWithEmail(
              email.trim(),
              password,
            )
            // Sans delai maximum, une requete qui ne revient jamais laisse
            // _isLoading a true -- et le bouton, desactive pendant le
            // chargement, ne repond plus du tout.
            .timeout(const Duration(seconds: 25));
        return EmailAuthOutcome.signedIn;
      }
      await authRepo.signUpWithEmail(
        email.trim(),
        password,
        name.trim(),
      );
      return authRepo.hasSession
          ? EmailAuthOutcome.signedIn
          : EmailAuthOutcome.needsEmailConfirmation;
    } finally {
      _setLoading(false);
    }
  }

  /// Google sign-in. Returns whether a session is open afterwards. Errors
  /// throw: pass them to [friendlyAuthErrorMessage].
  Future<bool> signInWithGoogle() async {
    final authRepo = ref.read(authRepositoryProvider);
    _setLoading(true);
    try {
      await authRepo.signInWithGoogle();
      return authRepo.hasSession;
    } finally {
      _setLoading(false);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Maps a raw auth exception (e.g. the Supabase client's
/// `AuthApiException(message: Invalid login credentials, statusCode: 400,
/// code: invalid_credentials)`) to a short message a customer can actually
/// act on. Matched on the exception's own toString() rather than importing
/// the exception type, since the client only needs a handful of known
/// substrings and this keeps the check trivially portable.
String friendlyAuthErrorMessage(AppLocalizations l10n, Object e) {
  final raw = e.toString().toLowerCase();
  if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) {
    return l10n.authErrorInvalidCredentials;
  }
  if (raw.contains('user already registered') || raw.contains('already registered')) {
    return l10n.authErrorAccountExists;
  }
  if (raw.contains('email not confirmed')) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (raw.contains('password') && raw.contains('6 characters')) {
    return l10n.passwordLength;
  }
  if (raw.contains('socketexception') ||
      raw.contains('network') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection')) {
    return l10n.authErrorNoInternet;
  }
  // Serveur injoignable ou en panne : 502/503/504 et les délais dépassés.
  // Sans ces cas, une panne Supabase tombait dans le message generique
  // « une erreur est survenue », qui laisse croire a une faute de saisie.
  if (raw.contains('timeout') || raw.contains('timed out')) {
    return l10n.authErrorTimeout;
  }
  if (raw.contains('statuscode: 50') ||
      raw.contains('502') ||
      raw.contains('503') ||
      raw.contains('504') ||
      raw.contains('service unavailable') ||
      raw.contains('bad gateway')) {
    return l10n.authErrorServiceUnavailable;
  }
  return l10n.authErrorGeneric;
}
