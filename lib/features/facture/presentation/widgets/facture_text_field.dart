import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import 'facture_colors.dart';

/// A rounded form field of the "Facture" page with an orange icon on the
/// left (reference, amount, phone). Errors show as soon as the user types.
class FactureTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextInputAction? textInputAction;

  const FactureTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: kFactureOrange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kFactureOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
    );
  }
}
