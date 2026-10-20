import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';

/// The fixed country code shown before the number.
const tunisianCountryCode = '+216';

/// "🇹🇳 +216 | 12 345 678" — the phone field of the phone screen.
///
/// The +216 is presentation, not input: it can't be edited or deleted. The
/// field holds the 8 local digits, grouped 2-3-3 while typing, and is
/// always left-to-right (even in Arabic) so the prefix stays on the left.
class TunisianPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  /// Called when the keyboard's "done" is pressed.
  final ValueChanged<String> onSubmitted;

  const TunisianPhoneField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  static OutlineInputBorder _border(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: onSubmitted,
        enabled: enabled,
        maxLength: 10, // 8 digits + the 2 spaces the formatter inserts
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: AppColors.textPrimary,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _TunisianPhoneFormatter(),
        ],
        decoration: InputDecoration(
          labelText: l.phoneNumber,
          hintText: '12 345 678',
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.45),
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const _CountryPrefix(),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          border: _border(AppColors.textSecondary.withValues(alpha: 0.25)),
          enabledBorder: _border(AppColors.textSecondary.withValues(alpha: 0.25)),
          focusedBorder: _border(AppColors.primary, width: 1.8),
          errorBorder: _border(Colors.red.shade400),
          focusedErrorBorder: _border(Colors.red.shade400, width: 1.8),
        ),
        validator: (_) {
          final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
          if (digits.length != 8) return l.phoneInvalid;
          return null;
        },
      ),
    );
  }
}

/// "🇹🇳 +216 |" at the start of the field.
class _CountryPrefix extends StatelessWidget {
  const _CountryPrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇹🇳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            tunisianCountryCode,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 26,
            color: AppColors.textSecondary.withValues(alpha: 0.22),
          ),
        ],
      ),
    );
  }
}

/// Formats 8 local Tunisian digits as `XX XXX XXX` while typing, and caps the
/// input at 8 digits so the field can never hold more than a valid number.
class _TunisianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      // Group as 2-3-3: a space goes before the 3rd and 6th digit.
      if (i == 2 || i == 5) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
