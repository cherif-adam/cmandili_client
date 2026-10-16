import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'reset_password_screen.dart';
import 'widgets/password_glass_card.dart';
import 'widgets/password_page_background.dart';
import 'widgets/password_page_icon.dart';
import 'widgets/password_submit_button.dart';
import 'widgets/password_text_field.dart';

/// "Mot de passe oublié ?": the e-mail field, "Envoyer le code", and a
/// link for those who already have a code (ResetPasswordScreen).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

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

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetOtp(_emailController.text.trim());

      if (!mounted) return;

      // Navigate to OTP + new-password screen, passing the email so the
      // verifyOtp call can reference it.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResetPasswordScreen(email: _emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                                "Enter your email and we'll send\nyou a 6-digit reset code.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: sw * 0.038,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: sh * 0.04),
                              PasswordGlassCard(
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      PasswordTextField(
                                        controller: _emailController,
                                        label: l.email,
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return l.pleaseEnterEmail;
                                          }
                                          if (!v.contains('@')) {
                                            return l.validEmail;
                                          }
                                          return null;
                                        },
                                      ),
                                      SizedBox(height: sh * 0.025),
                                      PasswordSubmitButton(
                                        isLoading: _isLoading,
                                        label: l.sendResetCode,
                                        onPressed: _sendCode,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: sh * 0.025),
                              // Already have the code?
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResetPasswordScreen(
                                        email: _emailController.text.trim()),
                                  ),
                                ),
                                child: Text(
                                  l.haveCodeEnterIt,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: sw * 0.037,
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
}
