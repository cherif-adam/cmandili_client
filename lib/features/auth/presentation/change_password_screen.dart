import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_screen.dart';

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
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  /// Le même minimum qu'à l'inscription. Le serveur applique le sien de toute
  /// façon ; ce contrôle-ci évite un aller-retour réseau pour rien.
  static const int _kMinLength = 6;

  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

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
        return l.pwdErrorTooShort(_kMinLength);
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

    setState(() => _saving = true);
    final code = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);

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
      final ok = await ref.read(authRepositoryProvider).signOutOtherDevices();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

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
            Text(
              l.pwdIntro,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),

            _field(
              controller: _currentCtrl,
              label: l.pwdCurrent,
              obscure: !_showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? l.pwdErrorRequired : null,
            ),
            const SizedBox(height: 16),

            _field(
              controller: _newCtrl,
              label: l.pwdNew,
              obscure: !_showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              validator: (v) {
                if (v == null || v.isEmpty) return l.pwdErrorRequired;
                if (v.length < _kMinLength) {
                  return l.pwdErrorTooShort(_kMinLength);
                }
                // Contrôlé ici ET dans le dépôt : ici pour le dire avant
                // l'aller-retour réseau, là-bas parce que le dépôt ne peut
                // pas supposer qu'un écran l'a fait.
                if (v == _currentCtrl.text) return l.pwdErrorSameAsOld;
                return null;
              },
            ),
            const SizedBox(height: 16),

            _field(
              controller: _confirmCtrl,
              label: l.pwdConfirm,
              obscure: !_showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return l.pwdErrorRequired;
                if (v != _newCtrl.text) return l.pwdErrorMismatch;
                return null;
              },
            ),

            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        l.changePassword,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            // Pour celui qui ne se souvient pas de l'actuel : le chemin par
            // code e-mail existe déjà, autant y mener d'ici plutôt que de le
            // laisser chercher.
            Center(
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                child: Text(l.forgotPassword),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
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
