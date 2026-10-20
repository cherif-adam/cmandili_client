import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per "Mot de passe oublié" screen on display (the argument
/// is a key the screen creates for itself), auto-disposed with it like the
/// State it replaces. Its state is "the code is being sent".
final forgotPasswordControllerProvider = NotifierProvider.autoDispose
    .family<ForgotPasswordController, bool, Object>(ForgotPasswordController.new);

/// Why the e-mail is refused. The screen turns it into a translated text.
enum ForgotPasswordEmailError { empty, invalid }

class ForgotPasswordController extends AutoDisposeFamilyNotifier<bool, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  bool build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Sends the 6-digit reset code to [email] (trimmed). Errors propagate:
  /// the screen shows them.
  Future<void> sendCode(String email) async {
    final auth = ref.read(authRepositoryProvider);
    state = true;
    try {
      await auth.sendPasswordResetOtp(email.trim());
    } finally {
      if (!_disposed) state = false;
    }
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  static ForgotPasswordEmailError? validateEmail(String? v) {
    if (v == null || v.isEmpty) return ForgotPasswordEmailError.empty;
    if (!v.contains('@')) return ForgotPasswordEmailError.invalid;
    return null;
  }
}
