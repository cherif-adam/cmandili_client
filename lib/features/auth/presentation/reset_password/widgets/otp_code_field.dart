import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// "Code à 8 chiffres" + a large centred field for the code from the
/// e-mail (digits only, widely spaced, green).
class OtpCodeField extends StatelessWidget {
  final TextEditingController controller;

  const OtpCodeField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(sw * 0.04),
          borderSide: side,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.eightDigitCode,
          style: TextStyle(
            fontSize: sw * 0.035,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: sh * 0.008),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: sw * 0.07,
            fontWeight: FontWeight.bold,
            letterSpacing: sw * 0.06,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            counterText: '', // hide the "0/8" counter
            filled: true,
            fillColor: AppColors.primary.withValues(alpha: 0.05),
            border: border(BorderSide.none),
            enabledBorder: border(BorderSide(
                color: AppColors.primary.withValues(alpha: 0.25), width: 1.5)),
            focusedBorder: border(const BorderSide(color: AppColors.primary, width: 2.5)),
            errorBorder: border(const BorderSide(color: AppColors.error, width: 1.5)),
            focusedErrorBorder: border(const BorderSide(color: AppColors.error, width: 2)),
            contentPadding: EdgeInsets.symmetric(vertical: sh * 0.022),
          ),
          validator: (v) {
            if (v == null || v.trim().length != 8) {
              return AppLocalizations.of(context)!.enterEightDigitCode;
            }
            return null;
          },
        ),
      ],
    );
  }
}
