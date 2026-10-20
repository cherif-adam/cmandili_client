import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per "Saisissez le code" screen on display (the argument
/// is a key the screen creates for itself), auto-disposed with it like the
/// State it replaces.
final resetPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ResetPasswordController, ResetPasswordState, Object>(
        ResetPasswordController.new);

@immutable
class ResetPasswordState {
  const ResetPasswordState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.obscureConfirm = true,
  });

  final bool isLoading;
  final bool obscurePassword;
  final bool obscureConfirm;

  ResetPasswordState copyWith({bool? isLoading, bool? obscurePassword, bool? obscureConfirm}) =>
      ResetPasswordState(
        isLoading: isLoading ?? this.isLoading,
        obscurePassword: obscurePassword ?? this.obscurePassword,
        obscureConfirm: obscureConfirm ?? this.obscureConfirm,
      );
}

/// Why a field is refused. The screen turns it into a translated text.
enum ResetPasswordFieldError { passwordEmpty, passwordTooShort, mismatch }

/// What a failed reset means for the customer.
enum ResetPasswordFailure { codeInvalid, passwordRejected, other }

class ResetPasswordController
    extends AutoDisposeFamilyNotifier<ResetPasswordState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  ResetPasswordState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const ResetPasswordState();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void togglePasswordVisibility() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void toggleConfirmVisibility() =>
      state = state.copyWith(obscureConfirm: !state.obscureConfirm);

  /// Verifies the e-mailed [code] (which opens a recovery session in
  /// Supabase), then sets [newPassword] within that session. Errors
  /// propagate; [classify] tells the screen what to say.
  Future<void> reset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = state.copyWith(isLoading: true);
    try {
      // Step 2: verify OTP → establishes a recovery session in Supabase
      await repo.verifyPasswordResetOtp(email: email, token: code.trim());

      // Step 3: update password within that session
      await repo.updatePassword(newPassword);
    } finally {
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Maps a raw Supabase error string to what went wrong.
  static ResetPasswordFailure classify(String raw) {
    if (raw.contains('Token has expired') || raw.contains('invalid')) {
      return ResetPasswordFailure.codeInvalid;
    }
    if (raw.contains('Password should be')) {
      return ResetPasswordFailure.passwordRejected;
    }
    return ResetPasswordFailure.other;
  }

  static ResetPasswordFieldError? validatePassword(String? v) {
    if (v == null || v.isEmpty) return ResetPasswordFieldError.passwordEmpty;
    if (v.length < 8) return ResetPasswordFieldError.passwordTooShort;
    return null;
  }

  static ResetPasswordFieldError? validateConfirmation(String? v, String password) =>
      v != password ? ResetPasswordFieldError.mismatch : null;

  /// Shows a masked email like  u****@gmail.com
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '$name****'
        : '${name[0]}${'*' * (name.length - 1)}';
    return '$masked@${parts[1]}';
  }
}
