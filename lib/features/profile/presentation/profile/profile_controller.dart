import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../auth/data/auth_repository.dart' show User;
import '../../../auth/providers/auth_provider.dart';
import '../../../bills/services/bill_reminder_service.dart';
import '../../providers/profile_repository_provider.dart';

/// One controller per profile tab on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces.
final profileControllerProvider = NotifierProvider.autoDispose
    .family<ProfileController, ProfileState, Object>(ProfileController.new);

@immutable
class ProfileState {
  const ProfileState({
    this.billRemindersEnabled = true,
    this.isUploading = false,
    this.localAvatar,
  });

  final bool billRemindersEnabled;

  /// Whether an upload is in progress, to show the loading overlay and
  /// prevent double-taps.
  final bool isUploading;

  /// When non-null, this local file is displayed immediately after the user
  /// picks an image — before (and after) the upload completes — so the UI
  /// feels instant. It falls back gracefully to the remote URL on error.
  final File? localAvatar;
}

class ProfileController extends AutoDisposeFamilyNotifier<ProfileState, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  ProfileState build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    _loadBillReminders();
    return const ProfileState();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  void _loadBillReminders() {
    BillReminderService.instance.isEnabled().then((v) {
      if (!_disposed) {
        state = ProfileState(
          billRemindersEnabled: v,
          isUploading: state.isUploading,
          localAvatar: state.localAvatar,
        );
      }
    });
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> setBillReminders(bool enabled) async {
    state = ProfileState(
      billRemindersEnabled: enabled,
      isUploading: state.isUploading,
      localAvatar: state.localAvatar,
    );
    await BillReminderService.instance.setEnabled(enabled);
  }

  /// Shows [file] at once (optimistic), uploads it, and reverts to the
  /// remote picture when the upload fails. Returns whether it succeeded.
  Future<bool> uploadAvatar(File file) async {
    final repo = ref.read(profileRepositoryProvider);
    state = ProfileState(
      billRemindersEnabled: state.billRemindersEnabled,
      isUploading: true,
      localAvatar: file,
    );

    final url = await repo.uploadProfilePicture(file);

    if (_disposed) return url != null;
    state = ProfileState(
      billRemindersEnabled: state.billRemindersEnabled,
      isUploading: false,
      // Revert optimistic image on failure.
      localAvatar: url == null ? null : state.localAvatar,
    );
    return url != null;
  }

  /// Really signs out; main.dart then shows the login screen.
  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

  void toggleTheme() => ref.read(themeProvider.notifier).toggleTheme();

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Priority: local file (just picked) → remote URL from auth metadata → none.
  /// Null when the user has no picture: a person icon is drawn instead.
  ImageProvider? avatarImage(User? authUser) {
    if (state.localAvatar != null) return FileImage(state.localAvatar!);
    final url = authUser?.photoURL;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  static String languageName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }
}
