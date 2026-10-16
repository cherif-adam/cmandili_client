import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import 'widgets/tunisian_phone_field.dart';

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
        phone: '$tunisianCountryCode$_localDigits',
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
                    const _PhoneIcon(),
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
                    TunisianPhoneField(
                      controller: _phoneCtrl,
                      enabled: !_saving,
                      onSubmitted: (_) => _isComplete && !_saving ? _save() : null,
                    ),
                    const SizedBox(height: 28),
                    _ContinueButton(
                      enabled: _isComplete && !_saving,
                      saving: _saving,
                      label: l.continueButton,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round green phone icon at the top.
class _PhoneIcon extends StatelessWidget {
  const _PhoneIcon();

  @override
  Widget build(BuildContext context) {
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
}

/// "Continuer" — grey until the 8 digits are typed, a spinner while saving.
class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final String label;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.enabled,
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
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
        child: saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
