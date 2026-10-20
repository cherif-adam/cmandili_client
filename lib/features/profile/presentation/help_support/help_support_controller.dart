import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/support_repository.dart';

final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => SupportRepository());

/// One controller per help screen on display (the argument is a key the
/// screen creates for itself), auto-disposed with it like the State it
/// replaces. Its state is "the ticket is being sent".
final helpSupportControllerProvider = NotifierProvider.autoDispose
    .family<HelpSupportController, bool, Object>(HelpSupportController.new);

class HelpSupportController extends AutoDisposeFamilyNotifier<bool, Object> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _disposed = false;

  @override
  bool build(Object screenKey) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Opens the ticket (subject and message trimmed). Errors propagate: the
  /// screen shows its own message.
  Future<void> submit({required String subject, required String message}) async {
    final repository = ref.read(supportRepositoryProvider);
    state = true;
    try {
      await repository.createTicket(subject: subject.trim(), message: message.trim());
    } finally {
      if (!_disposed) state = false;
    }
  }

  // ── Field rules ───────────────────────────────────────────────────────────

  /// Subject and message are both required.
  static bool isMissing(String? value) => value!.isEmpty;
}
