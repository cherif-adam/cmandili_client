import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository());

/// One controller per "Modifier le profil" screen on display (the argument
/// is a key the screen creates for itself), auto-disposed with it like the
/// State it replaces. Its state is the new avatar picked, if any.
final editProfileControllerProvider = NotifierProvider.autoDispose
    .family<EditProfileController, File?, Object>(EditProfileController.new);

class EditProfileController extends AutoDisposeFamilyNotifier<File?, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  @override
  File? build(Object screenKey) => null;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// What the auth session already knows, to fill the form at once.
  ({String name, String email}) initialValues() {
    final user = ref.read(authRepositoryProvider).currentUser;
    return (name: user?.displayName ?? '', email: user?.email ?? '');
  }

  /// The saved profile. [name] is null when the profile has no name (keep
  /// what the session gave); [phone] is '' when it has no phone. Null when
  /// the profile could not be read.
  Future<({String? name, String phone})?> loadProfile() async {
    final profile = await ref.read(profileRepositoryProvider).getUserProfile();
    if (profile == null) return null;
    final fullName = profile['full_name'] as String?;
    return (
      name: (fullName?.isNotEmpty ?? false) ? fullName : null,
      phone: profile['phone'] as String? ?? '',
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void setAvatar(File file) => state = file;

  /// Uploads the new avatar if one was picked, then saves the name and the
  /// phone (trimmed). Returns whether the profile update succeeded.
  Future<bool> save({required String name, required String phone}) async {
    final repo = ref.read(profileRepositoryProvider);
    final avatar = state;

    // Upload new avatar if selected
    if (avatar != null) {
      await repo.uploadProfilePicture(avatar);
    }

    return repo.updateProfile(
      fullName: name.trim(),
      phone: phone.trim(),
    );
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  /// The name is required.
  static bool isNameMissing(String? value) => value!.isEmpty;
}
