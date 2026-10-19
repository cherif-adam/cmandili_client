import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import 'courier_text_field.dart';

/// An 8-digit Tunisian phone field (sender or recipient). Errors show as
/// soon as the user types.
class CourierPhoneField extends StatelessWidget {
  static const _tunisianPhone = r'^\d{8}$';

  final TextEditingController controller;
  final IconData icon;

  /// Shown when the field is left empty, e.g. "Obligatoire — numéro du
  /// destinataire".
  final String requiredMessage;
  final double screenWidth;

  const CourierPhoneField({
    super.key,
    required this.controller,
    required this.icon,
    required this.requiredMessage,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: 8,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: courierInputDecoration(
        AppLocalizations.of(context)!.courierPhoneExample,
        icon,
        screenWidth,
      ).copyWith(counterText: ''),
      validator: (v) {
        final val = v?.trim() ?? '';
        if (val.isEmpty) return requiredMessage;
        if (!RegExp(_tunisianPhone).hasMatch(val)) {
          return AppLocalizations.of(context)!.commonInvalidPhone8;
        }
        return null;
      },
    );
  }
}
