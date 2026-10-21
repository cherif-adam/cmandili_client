import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/models/deletion_outcome.dart';
import '../../providers/account_deletion_provider.dart';
import 'delete_account_controller.dart';
import 'widgets/deletion_blockers_card.dart';
import 'widgets/deletion_confirm_form.dart';
import 'widgets/deletion_info_card.dart';
import 'widgets/deletion_load_error.dart';

/// « Supprimer mon compte » (exigence Google Play et Apple), de haut en bas :
///
///   DeletionInfoCard      ce qui part, ce qui reste
///   DeletionBlockersCard  ce qui bloque et quoi faire, s'il y a un blocage
///   DeletionConfirmForm   sinon : mot à taper + ré-authentification
///
/// UI seulement : la ré-authentification et l'appel au serveur sont dans
/// [DeleteAccountController] ; le dialogue de fin et la navigation restent
/// ici. La suppression elle-même se fait côté serveur.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  /// This screen's own controller (see [deleteAccountControllerProvider]).
  late final _provider = deleteAccountControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  final _wordCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _wordCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final blockers = ref.watch(accountDeletionBlockersProvider);
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccount)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(width * 0.05),
          children: [
            const DeletionInfoCard(),
            SizedBox(height: width * 0.06),
            blockers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => DeletionLoadError(
                onRetry: () => ref.invalidate(accountDeletionBlockersProvider),
              ),
              data: (list) => list.isNotEmpty
                  ? DeletionBlockersCard(blockers: list)
                  : DeletionConfirmForm(
                      formKey: _formKey,
                      wordController: _wordCtrl,
                      passwordController: _passwordCtrl,
                      method: controller.reauthMethod,
                      showPassword: state.showPassword,
                      busy: state.busy,
                      errorText: _errorText(l, state.errorCode),
                      onTogglePassword: controller.togglePassword,
                      onSubmit: _submit,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _errorText(AppLocalizations l, String? code) {
    switch (code) {
      case null:
        return null;
      case 'wrong_password':
        return l.deleteAccountErrorWrongPassword;
      case 'other_account':
        return l.deleteAccountErrorOtherGoogle;
      case 'reauth_required':
        return l.deleteAccountErrorReauth;
      case 'no_method':
        return l.deleteAccountErrorNoMethod;
      default:
        return l.deleteAccountErrorFailed;
    }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final status = await ref.read(_provider.notifier).submit(_passwordCtrl.text);
    if (!mounted || status != DeletionStatus.deleted) return;
    await _finish();
  }

  /// Le compte n'existe plus côté serveur. On le dit, puis on revient à la
  /// racine avant de nettoyer la session : c'est elle que main.dart bascule
  /// sur l'écran de connexion (même raison que la déconnexion du profil).
  Future<void> _finish() async {
    final l = AppLocalizations.of(context)!;
    // Lu avant de quitter l'écran : son contrôleur disparaît avec lui.
    final auth = ref.read(authRepositoryProvider);
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteAccountDoneTitle),
        content: Text(l.deleteAccountDoneBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.deleteAccountDoneOk),
          ),
        ],
      ),
    );
    navigator.popUntil((route) => route.isFirst);
    await auth.signOutAfterDeletion();
  }
}
