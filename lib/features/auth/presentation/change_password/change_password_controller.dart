import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// One controller per "Changer le mot de passe" screen on display (the
/// argument is a key the screen creates for itself), auto-disposed with it
/// like the State it replaces.
final changePasswordControllerProvider = NotifierProvider.autoDispose
    .family<ChangePasswordController, ChangePasswordState, Object>(
        ChangePasswordController.new);

@immutable
class ChangePasswordState {
  const ChangePasswordState({
    this.showCurrent = false,
    this.showNew = false,
    this.showConfirm = false,
    this.saving = false,
  });

  final bool showCurrent;
  final bool showNew;
  final bool showConfirm;
  final bool saving;

  ChangePasswordState copyWith({
    bool? showCurrent,
    bool? showNew,
    bool? showConfirm,
    bool? saving,
  }) =>
      ChangePasswordState(
        showCurrent: showCurrent ?? this.showCurrent,
        showNew: showNew ?? this.showNew,
        showConfirm: showConfirm ?? this.showConfirm,
        saving: saving ?? this.saving,
      );
}

/// Why a field is refused. The screen turns it into a translated text.
enum PasswordFieldError { required, tooShort, sameAsOld, mismatch }

class ChangePasswordController
    extends AutoDisposeFamilyNotifier<ChangePasswordState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  /// Le même minimum qu'à l'inscription. Le serveur applique le sien de toute
  /// façon ; ce contrôle-ci évite un aller-retour réseau pour rien.
  static const int minLength = 6;

  bool _disposed = false;

  @override
  ChangePasswordState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const ChangePasswordState();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void toggleCurrent() => state = state.copyWith(showCurrent: !state.showCurrent);

  void toggleNew() => state = state.copyWith(showNew: !state.showNew);

  void toggleConfirm() => state = state.copyWith(showConfirm: !state.showConfirm);

  /// Checks the current password (by signing in again with it), then sets
  /// the new one. Returns the repository's error code, null on success.
  Future<String?> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    state = state.copyWith(saving: true);
    try {
      return await auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } finally {
      if (!_disposed) state = state.copyWith(saving: false);
    }
  }

  /// Changing a password does NOT end the sessions already open elsewhere;
  /// this does. Returns whether it worked.
  Future<bool> signOutOtherDevices() =>
      ref.read(authRepositoryProvider).signOutOtherDevices();

  // ── Field rules ───────────────────────────────────────────────────────────

  static PasswordFieldError? validateCurrent(String? v) =>
      (v == null || v.isEmpty) ? PasswordFieldError.required : null;

  static PasswordFieldError? validateNew(String? v, String current) {
    if (v == null || v.isEmpty) return PasswordFieldError.required;
    if (v.length < minLength) return PasswordFieldError.tooShort;
    // Contrôlé ici ET dans le dépôt : ici pour le dire avant l'aller-retour
    // réseau, là-bas parce que le dépôt ne peut pas supposer qu'un écran
    // l'a fait.
    if (v == current) return PasswordFieldError.sameAsOld;
    return null;
  }

  static PasswordFieldError? validateConfirmation(String? v, String newPassword) {
    if (v == null || v.isEmpty) return PasswordFieldError.required;
    if (v != newPassword) return PasswordFieldError.mismatch;
    return null;
  }
}
