import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../delete_account_controller.dart';

/// Confirmation : taper le mot (SUPPRIMER, DELETE, حذف selon la langue), puis
/// prouver que c'est bien soi — mot de passe, ou reconnexion Google / Apple
/// pour un compte sans mot de passe. Le serveur refuse si cette preuve date de plus
/// de 5 minutes.
///
/// Affichage seul : l'état et l'envoi sont dans [DeleteAccountController].
class DeletionConfirmForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController wordController;
  final TextEditingController passwordController;

  /// 'password', 'google', 'apple' or null (see
  /// [DeleteAccountController.reauthMethod]).
  final String? method;
  final bool showPassword;
  final bool busy;
  final String? errorText;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const DeletionConfirmForm({
    super.key,
    required this.formKey,
    required this.wordController,
    required this.passwordController,
    required this.method,
    required this.showPassword,
    required this.busy,
    required this.errorText,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final word = l.deleteAccountConfirmWord;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.deleteAccountTypeWord(word),
            style: TextStyle(fontSize: width * 0.038, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: width * 0.02),
          TextFormField(
            controller: wordController,
            enabled: !busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: word,
              border: const OutlineInputBorder(),
            ),
            validator: (v) => DeleteAccountController.wordMatches(v, word)
                ? null
                : l.deleteAccountWordMismatch(word),
          ),
          SizedBox(height: width * 0.045),
          if (method == 'password') ...[
            Text(l.deleteAccountPasswordHint, style: TextStyle(fontSize: width * 0.036)),
            SizedBox(height: width * 0.02),
            TextFormField(
              controller: passwordController,
              enabled: !busy,
              obscureText: !showPassword,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.deleteAccountPasswordLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? l.deleteAccountErrorWrongPassword : null,
            ),
          ] else if (method == 'google')
            Text(l.deleteAccountGoogleHint, style: TextStyle(fontSize: width * 0.036))
          else if (method == 'apple')
            Text(l.deleteAccountAppleHint, style: TextStyle(fontSize: width * 0.036))
          else
            Text(
              l.deleteAccountErrorNoMethod,
              style: TextStyle(fontSize: width * 0.036, color: AppColors.error),
            ),
          if (errorText != null) ...[
            SizedBox(height: width * 0.03),
            Text(errorText!, style: TextStyle(fontSize: width * 0.035, color: AppColors.error)),
          ],
          SizedBox(height: width * 0.05),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: width * 0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(width * 0.03)),
            ),
            onPressed: (busy || method == null) ? null : onSubmit,
            child: busy
                ? SizedBox(
                    height: width * 0.05,
                    width: width * 0.05,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l.deleteAccountSubmit,
                    style: TextStyle(fontSize: width * 0.04, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
