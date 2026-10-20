import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../reset_password/reset_password_screen.dart';
import '../widgets/password_glass_card.dart';
import '../widgets/password_page_background.dart';
import '../widgets/password_page_icon.dart';
import '../widgets/password_submit_button.dart';
import '../widgets/password_text_field.dart';
import 'forgot_password_controller.dart';

/// "Mot de passe oublié ?": the e-mail field, "Envoyer le code", and a
/// link for those who already have a code (ResetPasswordScreen).
///
///   back button, then _Header, _EmailCard, _HaveCodeLink
///
/// UI only: sending the code and the e-mail rule live in
/// [ForgotPasswordController]; the field, the animation and the navigation
/// stay here.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  /// This screen's own controller (see [forgotPasswordControllerProvider]).
  late final _provider = forgotPasswordControllerProvider(Object());
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

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
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final isLoading = ref.watch(_provider);

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
                              const _Header(),
                              SizedBox(height: sh * 0.04),
                              _EmailCard(
                                formKey: _formKey,
                                emailController: _emailController,
                                isLoading: isLoading,
                                onSend: _sendCode,
                              ),
                              SizedBox(height: sh * 0.025),
                              _HaveCodeLink(onTap: _goToReset),
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

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(_provider.notifier).sendCode(_emailController.text);

      if (!mounted) return;

      // Navigate to OTP + new-password screen, passing the email so the
      // verifyOtp call can reference it.
      _goToReset();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _goToReset() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: _emailController.text.trim()),
      ),
    );
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
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Lock icon, "Mot de passe oublié ?" and the explanation.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final l = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PasswordPageIcon(icon: Icons.lock_reset_rounded),
        SizedBox(height: sh * 0.025),
        Text(
          l.forgotPassword,
          style: TextStyle(
            fontSize: sw * 0.07,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: sh * 0.01),
        Text(
          l.forgotPasswordIntro,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sw * 0.038,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// The glass card: e-mail field and "Envoyer le code".
class _EmailCard extends StatelessWidget {
  const _EmailCard({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSend,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSend;

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
            PasswordTextField(
              controller: emailController,
              label: l.email,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => switch (ForgotPasswordController.validateEmail(v)) {
                ForgotPasswordEmailError.empty => l.pleaseEnterEmail,
                ForgotPasswordEmailError.invalid => l.validEmail,
                null => null,
              },
            ),
            SizedBox(height: sh * 0.025),
            PasswordSubmitButton(
              isLoading: isLoading,
              label: l.sendResetCode,
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

/// "J'ai déjà un code" — straight to ResetPasswordScreen.
class _HaveCodeLink extends StatelessWidget {
  const _HaveCodeLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return TextButton(
      onPressed: onTap,
      child: Text(
        AppLocalizations.of(context)!.haveCodeEnterIt,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: sw * 0.037,
        ),
      ),
    );
  }
}
