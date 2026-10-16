import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A field of the forgot / reset password forms: light grey, rounded,
/// green icon; password fields have an 👁 button to show / hide.
class PasswordTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isPassword;
  final bool isObscure;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  const PasswordTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.isPassword = false,
    this.isObscure = false,
    this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: side,
        );

    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontSize: sw * 0.04,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.8),
          fontSize: sw * 0.038,
        ),
        prefixIcon: Icon(icon,
            color: AppColors.primary.withValues(alpha: 0.7), size: sw * 0.06),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: sw * 0.055,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        border: border(BorderSide.none),
        enabledBorder: border(BorderSide(
            color: AppColors.textLight.withValues(alpha: 0.1), width: 1.5)),
        focusedBorder: border(const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: border(const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: border(const BorderSide(color: AppColors.error, width: 2)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: sw * 0.05,
          vertical: sh * 0.02,
        ),
      ),
      validator: validator,
    );
  }
}
