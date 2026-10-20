import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/password_glass_card.dart';
import '../widgets/password_page_background.dart';
import '../widgets/password_page_icon.dart';
import '../widgets/password_submit_button.dart';
import '../widgets/password_text_field.dart';
import 'reset_password_controller.dart';
import 'widgets/otp_code_field.dart';

/// Second step of the OTP-based password-reset flow.
///
/// Receives the [email] the user typed in [ForgotPasswordScreen] so it can
/// pass it to `verifyOtp`.  The screen collects:
///   1. The 8-digit code from the email.
///   2. The new password (+ confirmation).
/// "Saisissez le code": the 8-digit code from the e-mail (OtpCodeField),
/// the new password twice, then "Réinitialiser le mot de passe".
///
///   back button, then _Header, _ResetCard; _PasswordChangedDialog on success
///
/// UI only: the reset, the error mapping, the field rules and the
/// show/hide toggles live in [ResetPasswordController].
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  /// This screen's own controller (see [resetPasswordControllerProvider]).
  late final _provider = resetPasswordControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

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
                              _Header(
                                maskedEmail:
                                    ResetPasswordController.maskEmail(widget.email),
                              ),
                              SizedBox(height: sh * 0.035),
                              _ResetCard(
                                formKey: _formKey,
                                otpController: _otpController,
                                passwordController: _passwordController,
                                confirmController: _confirmController,
                                state: state,
                                onTogglePassword: controller.togglePasswordVisibility,
                                onToggleConfirm: controller.toggleConfirmVisibility,
                                onSubmit: _resetPassword,
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

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(_provider.notifier).reset(
            email: widget.email,
            code: _otpController.text,
            newPassword: _passwordController.text,
          );

      if (!mounted) return;

      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError(_friendlyError(e.toString()));
    }
  }

  /// The translated message for a failed reset.
  String _friendlyError(String raw) {
    switch (ResetPasswordController.classify(raw)) {
      case ResetPasswordFailure.codeInvalid:
        return AppLocalizations.of(context)!.resetCodeInvalid;
      case ResetPasswordFailure.passwordRejected:
        return AppLocalizations.of(context)!.passwordLength;
      case ResetPasswordFailure.other:
        return raw;
    }
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
      builder: (_) => _PasswordChangedDialog(
        onBackToSignIn: () {
          // Pop both ResetPasswordScreen and ForgotPasswordScreen
          // back to the AuthScreen (the route that predates them).
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Shield icon, "Saisissez le code" and the masked e-mail it went to.
class _Header extends StatelessWidget {
  const _Header({required this.maskedEmail});

  final String maskedEmail;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          l.codeSentTo(maskedEmail),
          style: TextStyle(
            fontSize: sw * 0.036,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

/// The glass card: code, new password, confirmation, then the button.
class _ResetCard extends StatelessWidget {
  const _ResetCard({
    required this.formKey,
    required this.otpController,
    required this.passwordController,
    required this.confirmController,
    required this.state,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController otpController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final ResetPasswordState state;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    final l = AppLocalizations.of(context)!;
    return PasswordGlassCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OtpCodeField(controller: otpController),
            SizedBox(height: sh * 0.02),
            PasswordTextField(
              controller: passwordController,
              label: l.pwdNew,
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isObscure: state.obscurePassword,
              onToggle: onTogglePassword,
              validator: (v) => switch (ResetPasswordController.validatePassword(v)) {
                ResetPasswordFieldError.passwordEmpty => l.pleaseEnterPassword,
                ResetPasswordFieldError.passwordTooShort => l.passwordLength,
                _ => null,
              },
            ),
            SizedBox(height: sh * 0.02),
            PasswordTextField(
              controller: confirmController,
              label: l.confirmPasswordShort,
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isObscure: state.obscureConfirm,
              onToggle: onToggleConfirm,
              validator: (v) => ResetPasswordController.validateConfirmation(
                          v, passwordController.text) ==
                      null
                  ? null
                  : l.pwdErrorMismatch,
            ),
            SizedBox(height: sh * 0.03),
            PasswordSubmitButton(
              isLoading: state.isLoading,
              label: l.resetPasswordButton,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Mot de passe modifié" with "Retour à la connexion".
class _PasswordChangedDialog extends StatelessWidget {
  const _PasswordChangedDialog({required this.onBackToSignIn});

  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            onPressed: onBackToSignIn,
            child: Text(AppLocalizations.of(context)!.backToSignIn,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
