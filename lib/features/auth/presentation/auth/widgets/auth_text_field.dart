import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// A field of the login form (name, e-mail, password): light grey, rounded,
/// green icon; the password one has an 👁 button to show / hide it.
///
/// Validation: required; the e-mail must contain "@"; the password needs
/// 6 characters. The [fieldKey] goes on the TextFormField itself (the
/// integration test finds the fields by it).
class AuthTextField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final double screenWidth;
  final double screenHeight;
  final bool isPassword;
  final bool? isObscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;

  const AuthTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    required this.icon,
    required this.screenWidth,
    required this.screenHeight,
    this.isPassword = false,
    this.isObscure,
    this.onToggleObscure,
    this.keyboardType,
  });

  OutlineInputBorder _border(BorderSide side) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        borderSide: side,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return TextFormField(
      key: fieldKey,
      controller: controller,
      obscureText: isObscure ?? false,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontSize: screenWidth * 0.04,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          fontSize: screenWidth * 0.038,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary.withValues(alpha: 0.7),
          size: screenWidth * 0.06,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure! ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: screenWidth * 0.055,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        border: _border(BorderSide.none),
        enabledBorder: _border(BorderSide(
          color: AppColors.textLight.withValues(alpha: 0.1),
          width: 1.5,
        )),
        focusedBorder: _border(const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: _border(const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: _border(const BorderSide(color: AppColors.error, width: 2)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.02,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l.pleaseEnter(label);
        }
        if (label == l.email && !value.contains('@')) {
          return l.validEmail;
        }
        if (label == l.password && value.length < 6) {
          return l.passwordLength;
        }
        return null;
      },
    );
  }
}
