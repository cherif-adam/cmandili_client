import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import 'change_password_controller.dart';
import '../forgot_password/forgot_password_screen.dart';

/// Changer son mot de passe en étant connecté.
///
/// Jusqu'ici le seul chemin était « Mot de passe oublié » : recevoir un code
/// par e-mail pour changer un mot de passe qu'on connaît déjà. Cet écran fait
/// la même chose sans passer par la boîte mail — et garde le lien vers l'autre
/// chemin pour celui qui, lui, a vraiment oublié.
///
/// Le mot de passe actuel est vérifié AVANT le changement, en se reconnectant
/// avec. C'est la seule vérification que Supabase offre, et elle est
/// indispensable : sans elle, un téléphone laissé déverrouillé suffirait à
/// changer le mot de passe du compte.
///
///   _Intro, _PasswordFields, _SubmitButton, _ForgotLink
///
/// UI only: the show/hide toggles, the field rules, the change and the
/// other-devices sign-out live in [ChangePasswordController]; the error
/// sentences, the dialog and the navigation stay here.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  /// This screen's own controller (see [changePasswordControllerProvider]).
  late final _provider = changePasswordControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.changePassword),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _Intro(),
            const SizedBox(height: 24),
            _PasswordFields(
              currentCtrl: _currentCtrl,
              newCtrl: _newCtrl,
              confirmCtrl: _confirmCtrl,
              state: state,
              controller: controller,
            ),
            const SizedBox(height: 28),
            _SubmitButton(saving: state.saving, onPressed: _submit),
            const SizedBox(height: 12),
            _ForgotLink(enabled: !state.saving),
          ],
        ),
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Traduit le code d'erreur renvoyé par le dépôt.
  ///
  /// Le dépôt ne connaît pas la langue du client et Supabase répond en
  /// anglais : c'est ici, au plus près de l'affichage, que l'erreur devient
  /// une phrase.
  String _errorText(AppLocalizations l, String code) {
    switch (code) {
      case 'wrong_current':
        return l.pwdErrorWrongCurrent;
      case 'same_as_old':
        return l.pwdErrorSameAsOld;
      case 'too_short':
        return l.pwdErrorTooShort(ChangePasswordController.minLength);
      case 'reauth_needed':
        return l.pwdErrorReauthNeeded;
      case 'no_session':
        return l.pwdErrorNoSession;
      default:
        return l.pwdErrorFailed;
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(_provider.notifier);
    final code = await controller.change(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;

    if (code != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorText(l, code)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Changer un mot de passe ne ferme PAS les sessions déjà ouvertes
    // ailleurs. C'est précisément ce qu'on veut proposer à quelqu'un qui
    // change son mot de passe parce qu'il le croit compromis.
    final alsoSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.pwdChangedTitle),
        content: Text(l.pwdChangedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.pwdKeepOtherDevices),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.pwdSignOutOthers),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (alsoSignOut == true) {
      final ok = await controller.signOutOtherDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l.pwdOtherDevicesSignedOut : l.pwdErrorFailed),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.pwdChangedTitle),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Why the current password is asked.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.pwdIntro,
      style: const TextStyle(
          fontSize: 14, color: AppColors.textSecondary, height: 1.4),
    );
  }
}

/// Current password, new password, confirmation.
class _PasswordFields extends StatelessWidget {
  const _PasswordFields({
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.state,
    required this.controller,
  });

  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final ChangePasswordState state;
  final ChangePasswordController controller;

  String? _text(AppLocalizations l, PasswordFieldError? error) => switch (error) {
        PasswordFieldError.required => l.pwdErrorRequired,
        PasswordFieldError.tooShort => l.pwdErrorTooShort(ChangePasswordController.minLength),
        PasswordFieldError.sameAsOld => l.pwdErrorSameAsOld,
        PasswordFieldError.mismatch => l.pwdErrorMismatch,
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PasswordField(
          controller: currentCtrl,
          label: l.pwdCurrent,
          obscure: !state.showCurrent,
          onToggle: controller.toggleCurrent,
          validator: (v) => _text(l, ChangePasswordController.validateCurrent(v)),
        ),
        const SizedBox(height: 16),

        _PasswordField(
          controller: newCtrl,
          label: l.pwdNew,
          obscure: !state.showNew,
          onToggle: controller.toggleNew,
          validator: (v) =>
              _text(l, ChangePasswordController.validateNew(v, currentCtrl.text)),
        ),
        const SizedBox(height: 16),

        _PasswordField(
          controller: confirmCtrl,
          label: l.pwdConfirm,
          obscure: !state.showConfirm,
          onToggle: controller.toggleConfirm,
          validator: (v) => _text(
              l, ChangePasswordController.validateConfirmation(v, newCtrl.text)),
        ),
      ],
    );
  }
}

/// "Changer le mot de passe", a spinner while saving.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                AppLocalizations.of(context)!.changePassword,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

/// Pour celui qui ne se souvient pas de l'actuel : le chemin par code e-mail
/// existe déjà, autant y mener d'ici plutôt que de le laisser chercher.
class _ForgotLink extends StatelessWidget {
  const _ForgotLink({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: !enabled
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
        child: Text(AppLocalizations.of(context)!.forgotPassword),
      ),
    );
  }
}

/// A password field with an 👁 button to show / hide what is typed.
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: onToggle,
          tooltip: label,
        ),
      ),
      validator: validator,
    );
  }
}
