import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'widgets/otp_code_field.dart';
import 'widgets/password_glass_card.dart';
import 'widgets/password_page_background.dart';
import 'widgets/password_page_icon.dart';
import 'widgets/password_submit_button.dart';
import 'widgets/password_text_field.dart';

/// Second step of the OTP-based password-reset flow.
///
/// Receives the [email] the user typed in [ForgotPasswordScreen] so it can
/// pass it to `verifyOtp`.  The screen collects:
///   1. The 8-digit code from the email.
///   2. The new password (+ confirmation).
/// "Saisissez le code": the 8-digit code from the e-mail (OtpCodeField),
/// the new password twice, then "Réinitialiser le mot de passe".
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // â”€â”€ Core logic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = ref.read(authRepositoryProvider);

    try {
      // Step 2: verify OTP â†’ establishes a recovery session in Supabase
      await repo.verifyPasswordResetOtp(
        email: widget.email,
        token: _otpController.text.trim(),
      );

      // Step 3: update password within that session
      await repo.updatePassword(_passwordController.text);

      if (!mounted) return;

      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps raw Supabase error strings to human-readable messages.
  String _friendlyError(String raw) {
    if (raw.contains('Token has expired') || raw.contains('invalid')) {
      return AppLocalizations.of(context)!.resetCodeInvalid;
    }
    if (raw.contains('Password should be')) {
      return AppLocalizations.of(context)!.passwordLength;
    }
    return raw;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.pwdChangedTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.passwordUpdatedBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Pop both ResetPasswordScreen and ForgotPasswordScreen
                // back to the AuthScreen (the route that predates them).
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(AppLocalizations.of(context)!.backToSignIn,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          const PasswordPageBackground(),
          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: sw * 0.06),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
                              const PasswordPageIcon(icon: Icons.shield_rounded),
                              SizedBox(height: sh * 0.02),
                              Text(
                                l.enterResetCode,
                                style: TextStyle(
                                  fontSize: sw * 0.065,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: sh * 0.008),
                              // Masked e-mail, for confirmation
                              Text(
                                l.codeSentTo(_maskEmail(widget.email)),
                                style: TextStyle(
                                  fontSize: sw * 0.036,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              SizedBox(height: sh * 0.035),
                              PasswordGlassCard(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      OtpCodeField(controller: _otpController),
                                      SizedBox(height: sh * 0.02),
                                      PasswordTextField(
                                        controller: _passwordController,
                                        label: l.pwdNew,
                                        icon: Icons.lock_outline_rounded,
                                        isPassword: true,
                                        isObscure: _obscurePassword,
                                        onToggle: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return l.pleaseEnterPassword;
                                          }
                                          if (v.length < 8) {
                                            return l.passwordLength;
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: sh * 0.02),
                                      PasswordTextField(
                                        controller: _confirmController,
                                        label: l.confirmPasswordShort,
                                        icon: Icons.lock_outline_rounded,
                                        isPassword: true,
                                        isObscure: _obscureConfirm,
                                        onToggle: () => setState(
                                            () => _obscureConfirm = !_obscureConfirm),
                                        validator: (v) {
                                          if (v != _passwordController.text) {
                                            return l.pwdErrorMismatch;
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: sh * 0.03),
                                      PasswordSubmitButton(
                                        isLoading: _isLoading,
                                        label: l.resetPasswordButton,
                                        onPressed: _resetPassword,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a masked email like  u****@gmail.com
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '$name****'
        : '${name[0]}${'*' * (name.length - 1)}';
    return '$masked@${parts[1]}';
  }
}
