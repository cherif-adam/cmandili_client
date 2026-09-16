import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_repository.dart';

/// Mandatory post-auth gate that collects the user's phone number when their
/// `profiles.phone` is null or empty. The driver and partner apps need a
/// reachable phone for every customer; without one, deliveries break.
///
/// Cmandili operates only in Tunisia, so the country code is not something the
/// user picks or types: `+216` is rendered as a fixed, non-editable prefix and
/// the field itself holds exactly the 8 local digits. Whatever the user types,
/// the value persisted is always the full E.164 form (`+216XXXXXXXX`) so the
/// driver/partner apps can dial it directly.
class PhoneGateScreen extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const PhoneGateScreen({super.key, required this.onSaved});

  @override
  ConsumerState<PhoneGateScreen> createState() => _PhoneGateScreenState();
}

class _PhoneGateScreenState extends ConsumerState<PhoneGateScreen> {
  static const _countryCode = '+216';

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _profileRepo = ProfileRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Drives the enabled/disabled state of the continue button as the user types.
    _phoneCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onChanged);
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// The 8 local digits, stripped of the spaces the input formatter adds.
  String get _localDigits => _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

  bool get _isComplete => _localDigits.length == 8;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Always persist E.164 -- never the bare local digits.
      final ok = await _profileRepo.updateProfile(
        phone: '$_countryCode$_localDigits',
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok) {
        widget.onSaved();
      } else {
        _showError(AppLocalizations.of(context)!.failedToUpdateProfile);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: Text(l.logout),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              // Keeps the card from stretching edge-to-edge on tablets.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIcon(),
                    const SizedBox(height: 28),
                    Text(
                      l.addYourPhoneNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.phoneRequiredExplain,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildPhoneField(l),
                    const SizedBox(height: 28),
                    _buildContinueButton(l),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.16),
              AppColors.primary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: const Icon(
          Icons.phone_in_talk_rounded,
          size: 40,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPhoneField(AppLocalizations l) {
    return Directionality(
      // The number itself is always LTR, even in Arabic, so the +216 prefix
      // stays glued to the left of the digits instead of flipping sides.
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _isComplete && !_saving ? _save() : null,
        enabled: !_saving,
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
          // The country code is presentation, not input: it can't be edited,
          // selected or deleted, and it is always visible.
          prefixIcon: _buildCountryPrefix(),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          border: _border(AppColors.textSecondary.withValues(alpha: 0.25)),
          enabledBorder: _border(AppColors.textSecondary.withValues(alpha: 0.25)),
          focusedBorder: _border(AppColors.primary, width: 1.8),
          errorBorder: _border(Colors.red.shade400),
          focusedErrorBorder: _border(Colors.red.shade400, width: 1.8),
        ),
        validator: (_) {
          if (_localDigits.length != 8) return l.phoneInvalid;
          return null;
        },
      ),
    );
  }

  Widget _buildCountryPrefix() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🇹🇳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text(
            _countryCode,
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

  OutlineInputBorder _border(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _buildContinueButton(AppLocalizations l) {
    final enabled = _isComplete && !_saving;
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.textSecondary.withValues(alpha: 0.18),
          disabledForegroundColor: Colors.white,
          elevation: enabled ? 2 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                l.continueButton,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
