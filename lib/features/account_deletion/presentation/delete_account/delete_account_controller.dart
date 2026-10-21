import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/models/deletion_outcome.dart';
import '../../providers/account_deletion_provider.dart';

/// One controller per "Supprimer mon compte" screen on display (the argument
/// is a key the screen creates for itself), auto-disposed with it.
final deleteAccountControllerProvider = NotifierProvider.autoDispose
    .family<DeleteAccountController, DeleteAccountState, Object>(
        DeleteAccountController.new);

@immutable
class DeleteAccountState {
  const DeleteAccountState({
    this.showPassword = false,
    this.busy = false,
    this.errorCode,
  });

  final bool showPassword;

  /// Re-authentication or server call in progress: the form is locked.
  final bool busy;

  /// Why the last attempt failed; the screen turns it into a sentence.
  ///   wrong_password  other_account  reauth_required  no_method  failed
  final String? errorCode;

  DeleteAccountState copyWith({
    bool? showPassword,
    bool? busy,
    String? Function()? errorCode,
  }) =>
      DeleteAccountState(
        showPassword: showPassword ?? this.showPassword,
        busy: busy ?? this.busy,
        errorCode: errorCode != null ? errorCode() : this.errorCode,
      );
}

class DeleteAccountController
    extends AutoDisposeFamilyNotifier<DeleteAccountState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  DeleteAccountState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return const DeleteAccountState();
  }

  /// 'password', 'google', 'apple', or null when the app offers no way to prove who
  /// the user is (the form then only shows "contact the team").
  String? get reauthMethod => ref.read(authRepositoryProvider).reauthMethod;

  /// The typed word must be the screen's word (SUPPRIMER, DELETE, حذف),
  /// spaces and case aside.
  static bool wordMatches(String? typed, String word) =>
      (typed ?? '').trim().toUpperCase() == word.toUpperCase();

  // ── User actions ──────────────────────────────────────────────────────────

  void togglePassword() =>
      state = state.copyWith(showPassword: !state.showPassword);

  /// Proves who the user is (password, or the same Google / Apple account
  /// again),
  /// then asks the server to delete the account.
  ///
  /// Returns the server's answer, or null when it never got that far
  /// ([DeleteAccountState.errorCode] then says why). On
  /// [DeletionStatus.deleted] the form stays locked: the screen signs out.
  Future<DeletionStatus?> submit(String password) async {
    final method = reauthMethod;
    if (method == null) {
      state = state.copyWith(errorCode: () => 'no_method');
      return null;
    }

    state = state.copyWith(busy: true, errorCode: () => null);

    final auth = ref.read(authRepositoryProvider);
    final reauth = switch (method) {
      'password' => await auth.reauthenticateWithPassword(password),
      'apple' => await auth.reauthenticateWithApple(),
      _ => await auth.reauthenticateWithGoogle(),
    };
    if (_disposed) return null;
    if (reauth != null) {
      // Closing the Google picker is not an error.
      state = state.copyWith(
        busy: false,
        errorCode: () => reauth == 'cancelled' ? null : reauth,
      );
      return null;
    }

    final outcome =
        await ref.read(accountDeletionRepositoryProvider).deleteAccount();
    if (_disposed) return outcome.status;

    switch (outcome.status) {
      case DeletionStatus.deleted:
        break;
      case DeletionStatus.blocked:
        state = state.copyWith(busy: false);
        // Something new blocks (an order arrived meanwhile): the screen
        // shows the fresh list.
        ref.invalidate(accountDeletionBlockersProvider);
      case DeletionStatus.reauthRequired:
        state = state.copyWith(busy: false, errorCode: () => 'reauth_required');
      case DeletionStatus.failed:
        state = state.copyWith(busy: false, errorCode: () => 'failed');
    }
    return outcome.status;
  }
}
