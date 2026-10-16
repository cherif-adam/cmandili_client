import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'courier_colors.dart';

/// The white rounded look shared by every field of the "Colis" page
/// (grey border, purple when focused, red on error).
InputDecoration courierInputDecoration(String hint, IconData icon, double w) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.textSecondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(w * 0.03),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(w * 0.03),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(w * 0.03),
      borderSide: const BorderSide(color: kCourierPurple, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(w * 0.03),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(w * 0.03),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

/// A text field of the "Colis" page (recipient name, contents, declared
/// value, "remis à…").
class CourierTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final double screenWidth;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  const CourierTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.screenWidth,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      decoration: courierInputDecoration(hint, icon, screenWidth),
      validator: validator,
    );
  }
}
