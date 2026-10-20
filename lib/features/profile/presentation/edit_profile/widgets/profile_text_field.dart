import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// A rounded text field with a green icon, as used on the edit-profile
/// screen. Grey background when [enabled] is false (e.g. the e-mail).
class ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final String? Function(String?)? validator;

  const ProfileTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }
}
