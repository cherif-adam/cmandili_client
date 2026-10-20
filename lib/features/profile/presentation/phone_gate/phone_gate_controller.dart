import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_repository_provider.dart';
import 'widgets/tunisian_phone_field.dart' show tunisianCountryCode;

/// One controller per phone gate on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is "the number is being saved".
final phoneGateControllerProvider = NotifierProvider.autoDispose
    .family<PhoneGateController, bool, Object>(PhoneGateController.new);

class PhoneGateController extends AutoDisposeFamilyNotifier<bool, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  bool build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Saves the number typed in [fieldText] on the profile, always in E.164
  /// (`+216XXXXXXXX`) — never the bare local digits. Returns whether the
  /// profile update succeeded; other failures throw.
  Future<bool> save(String fieldText) async {
    final repo = ref.read(profileRepositoryProvider);
    state = true;
    try {
      return await repo.updateProfile(
        phone: '$tunisianCountryCode${localDigits(fieldText)}',
      );
    } finally {
      if (!_disposed) state = false;
    }
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// The 8 local digits, stripped of the spaces the input formatter adds.
  static String localDigits(String fieldText) =>
      fieldText.replaceAll(RegExp(r'[^0-9]'), '');

  static bool isComplete(String fieldText) => localDigits(fieldText).length == 8;
}
