import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/debug/build_info.dart';
import 'auth_controller.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_logo_header.dart';
import 'widgets/auth_submit_button.dart';
import 'widgets/auth_tab_bar.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/forgot_password_link.dart';
import 'widgets/glass_card.dart';
import 'widgets/language_cycle_button.dart';
import 'widgets/or_divider.dart';
import 'widgets/social_sign_in_button.dart';

/// Sign in / sign up, top to bottom:
///
///   background (green gradient + drifting circles), LanguageCycleButton
///   AuthLogoHeader     logo, "Amana", "Bienvenue"
///   GlassCard
///     AuthTabBar       Se connecter | S'inscrire
///     AuthTextField    (name), e-mail, password
///     ForgotPasswordLink, AuthSubmitButton
///     OrDivider, SocialSignInButton (Google)
///
///   sections: _LogoHeader, _AuthCard, _BuildLabel
///
/// UI only: signing in / up, the loading state, the show/hide toggle and
/// the error messages live in [AuthScreenController]; the tabs, the
/// animations, the fields and the navigation stay here.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  /// This screen's own controller (see [authScreenControllerProvider]).
  late final _provider = authScreenControllerProvider(Object());

  late TabController _tabController;
  late AnimationController _animationController;
  late AnimationController _backgroundAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _backgroundAnimationController,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _backgroundAnimationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final state = ref.watch(_provider);

    return Scaffold(
      body: Stack(
        children: [
          const AuthGradientBackground(),
          AuthFloatingCircles(
            animation: _rotationAnimation,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),

          // 🌐 top right
          Positioned(
            top: 0,
            right: 0,
            child: LanguageCycleButton(
              screenWidth: screenWidth,
              screenHeight: screenHeight,
            ),
          ),

          // Logo, then the login card
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: screenWidth * 0.06,
                right: screenWidth * 0.06,
                top: screenHeight * 0.06,
                bottom: screenHeight * 0.02,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight
                        - screenHeight * 0.08
                        - MediaQuery.of(context).padding.top
                        - MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _LogoHeader(fade: _fadeAnimation, scale: _scaleAnimation),
                        SizedBox(height: screenHeight * 0.04),
                        _AuthCard(
                          slide: _slideAnimation,
                          fade: _fadeAnimation,
                          tabController: _tabController,
                          onTabTap: (_) => setState(() {}),
                          formKey: _formKey,
                          nameController: _nameController,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          isLoading: state.isLoading,
                          obscurePassword: state.obscurePassword,
                          onToggleObscure:
                              ref.read(_provider.notifier).toggleObscurePassword,
                          onSubmit: _handleEmailAuth,
                          onGoogle: _handleGoogleSignIn,
                        ),
                        SizedBox(height: screenHeight * 0.01),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Build label (debug builds only): tells whether the phone runs the
          // latest build or an old installation.
          if (BuildInfo.label != null) const _BuildLabel(),
        ],
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  /// Un message par-dessus l'ecran, toujours visible.
  ///
  /// Les erreurs peintes sous un champ passent inapercues quand le clavier
  /// couvre le bas du formulaire.
  void _showAuthMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAuthError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            friendlyAuthErrorMessage(AppLocalizations.of(context)!, e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    // Le SEUL chemin muet de tout l'ecran etait ce `return` : pas de message,
    // pas de roue, rien. `validate()` peint bien une erreur sous le champ
    // fautif, mais ce champ peut etre hors ecran quand le clavier est ouvert,
    // et le bouton passe alors pour mort. Un message par-dessus dit au moins
    // qu'il y a quelque chose a corriger.
    if (!_formKey.currentState!.validate()) {
      _showAuthMessage(AppLocalizations.of(context)!.authCheckFormFields);
      return;
    }

    try {
      final outcome = await ref.read(_provider.notifier).submitEmail(
            isSignIn: _tabController.index == 0,
            email: _emailController.text,
            password: _passwordController.text,
            name: _nameController.text,
          );

      // Account created but no session: the project requires the user to
      // confirm their email first. Say so, instead of leaving the form
      // sitting there as if nothing happened.
      if (outcome == EmailAuthOutcome.needsEmailConfirmation) {
        if (mounted) {
          _tabController.animateTo(0); // ready to sign in once confirmed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.authAccountCreatedConfirmEmail,
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      // Signed in. main.dart swaps its root to Home by itself; if this login
      // screen was pushed on top of it (as the old logout did), close it so
      // Home is actually visible instead of hidden underneath.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showAuthError(e);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final hasSession = await ref.read(_provider.notifier).signInWithGoogle();
      // Same as email sign-in: never leave a pushed login screen over Home.
      if (mounted && hasSession && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showAuthError(e);
    }
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// Logo, "Amana", "Bienvenue" — fading and scaling in.
class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.fade, required this.scale});

  final Animation<double> fade;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: AuthLogoHeader(
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      ),
    );
  }
}

/// The glass card, sliding up: tabs, the form (name on sign-up, e-mail,
/// password, "Mot de passe oublié ?", submit), then "ou" and Google.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.slide,
    required this.fade,
    required this.tabController,
    required this.onTabTap,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogle,
  });

  final Animation<Offset> slide;
  final Animation<double> fade;
  final TabController tabController;
  final ValueChanged<int> onTabTap;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final l = AppLocalizations.of(context)!;
    final isSignIn = tabController.index == 0;

    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: fade,
        child: GlassCard(
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthTabBar(
                controller: tabController,
                onTap: onTabTap,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
              SizedBox(height: screenHeight * 0.025),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    if (!isSignIn) ...[
                      AuthTextField(
                        fieldKey: const Key('auth_name'),
                        controller: nameController,
                        label: l.fullName,
                        icon: Icons.person_outline_rounded,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                      ),
                      SizedBox(height: screenHeight * 0.015),
                    ],
                    AuthTextField(
                      fieldKey: const Key('auth_email'),
                      controller: emailController,
                      label: l.email,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    AuthTextField(
                      fieldKey: const Key('auth_password'),
                      controller: passwordController,
                      label: l.password,
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      isObscure: obscurePassword,
                      onToggleObscure: onToggleObscure,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    if (isSignIn)
                      ForgotPasswordLink(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                      ),
                    SizedBox(height: screenHeight * 0.015),
                    AuthSubmitButton(
                      isLoading: isLoading,
                      label: isSignIn ? l.signIn : l.createAccount,
                      onPressed: onSubmit,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              OrDivider(screenWidth: screenWidth),
              SizedBox(height: screenHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SocialSignInButton(
                    icon: Icons.g_mobiledata_rounded,
                    onPressed: isLoading ? null : onGoogle,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The build label at the very bottom (debug builds only).
class _BuildLabel extends StatelessWidget {
  const _BuildLabel();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 6,
      child: IgnorePointer(
        child: Text(
          BuildInfo.label!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
