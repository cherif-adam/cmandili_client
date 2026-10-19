import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/debug/build_info.dart';
import '../providers/auth_provider.dart';
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

/// Maps a raw auth exception (e.g. the Supabase client's
/// `AuthApiException(message: Invalid login credentials, statusCode: 400,
/// code: invalid_credentials)`) to a short message a customer can actually
/// act on. Matched on the exception's own toString() rather than importing
/// the exception type, since the client only needs a handful of known
/// substrings and this keeps the check trivially portable.
String friendlyAuthErrorMessage(AppLocalizations l10n, Object e) {
  final raw = e.toString().toLowerCase();
  if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) {
    return l10n.authErrorInvalidCredentials;
  }
  if (raw.contains('user already registered') || raw.contains('already registered')) {
    return l10n.authErrorAccountExists;
  }
  if (raw.contains('email not confirmed')) {
    return l10n.authErrorEmailNotConfirmed;
  }
  if (raw.contains('password') && raw.contains('6 characters')) {
    return l10n.passwordLength;
  }
  if (raw.contains('socketexception') ||
      raw.contains('network') ||
      raw.contains('failed host lookup') ||
      raw.contains('connection')) {
    return l10n.authErrorNoInternet;
  }
  // Serveur injoignable ou en panne : 502/503/504 et les délais dépassés.
  // Sans ces cas, une panne Supabase tombait dans le message generique
  // « une erreur est survenue », qui laisse croire a une faute de saisie.
  if (raw.contains('timeout') || raw.contains('timed out')) {
    return l10n.authErrorTimeout;
  }
  if (raw.contains('statuscode: 50') ||
      raw.contains('502') ||
      raw.contains('503') ||
      raw.contains('504') ||
      raw.contains('service unavailable') ||
      raw.contains('bad gateway')) {
    return l10n.authErrorServiceUnavailable;
  }
  return l10n.authErrorGeneric;
}

/// Sign in / sign up, top to bottom:
///
///   background (green gradient + drifting circles), LanguageCycleButton
///   AuthLogoHeader     logo, "Amana", "Bienvenue"
///   GlassCard
///     AuthTabBar       Se connecter | S'inscrire
///     AuthTextField    (name), e-mail, password
///     ForgotPasswordLink, AuthSubmitButton
///     OrDivider, SocialSignInButton (Google)
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
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
  
  bool _isLoading = false;
  bool _obscurePassword = true;

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

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      if (_tabController.index == 0) {
        await authRepo
            .signInWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
            )
            // Sans delai maximum, une requete qui ne revient jamais laisse
            // _isLoading a true -- et le bouton, desactive pendant le
            // chargement, ne repond plus du tout.
            .timeout(const Duration(seconds: 25));

      } else {
        await authRepo.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
        // Account created but no session: the project requires the user to
        // confirm their email first. Say so, instead of leaving the form
        // sitting there as if nothing happened.
        if (!authRepo.hasSession) {
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
      }

      // Signed in. main.dart swaps its root to Home by itself; if this login
      // screen was pushed on top of it (as the old logout did), close it so
      // Home is actually visible instead of hidden underneath.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                friendlyAuthErrorMessage(AppLocalizations.of(context)!, e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSocialSignIn(Future<void> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      await signInMethod();
      // Same as email sign-in: never leave a pushed login screen over Home.
      if (mounted &&
          ref.read(authRepositoryProvider).hasSession &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                friendlyAuthErrorMessage(AppLocalizations.of(context)!, e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final l = AppLocalizations.of(context)!;
    final isSignIn = _tabController.index == 0;

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
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: AuthLogoHeader(
                              screenWidth: screenWidth,
                              screenHeight: screenHeight,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.04),
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: GlassCard(
                              screenWidth: screenWidth,
                              screenHeight: screenHeight,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AuthTabBar(
                                    controller: _tabController,
                                    onTap: (_) => setState(() {}),
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                  ),
                                  SizedBox(height: screenHeight * 0.025),
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      children: [
                                        if (!isSignIn) ...[
                                          AuthTextField(
                                            fieldKey: const Key('auth_name'),
                                            controller: _nameController,
                                            label: l.fullName,
                                            icon: Icons.person_outline_rounded,
                                            screenWidth: screenWidth,
                                            screenHeight: screenHeight,
                                          ),
                                          SizedBox(height: screenHeight * 0.015),
                                        ],
                                        AuthTextField(
                                          fieldKey: const Key('auth_email'),
                                          controller: _emailController,
                                          label: l.email,
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          screenWidth: screenWidth,
                                          screenHeight: screenHeight,
                                        ),
                                        SizedBox(height: screenHeight * 0.015),
                                        AuthTextField(
                                          fieldKey: const Key('auth_password'),
                                          controller: _passwordController,
                                          label: l.password,
                                          icon: Icons.lock_outline_rounded,
                                          isPassword: true,
                                          isObscure: _obscurePassword,
                                          onToggleObscure: () {
                                            setState(() => _obscurePassword = !_obscurePassword);
                                          },
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
                                          isLoading: _isLoading,
                                          label: isSignIn ? l.signIn : l.createAccount,
                                          onPressed: _handleEmailAuth,
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
                                        onPressed: _isLoading
                                            ? null
                                            : () => _handleSocialSignIn(ref
                                                .read(authRepositoryProvider)
                                                .signInWithGoogle),
                                        screenWidth: screenWidth,
                                        screenHeight: screenHeight,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
          if (BuildInfo.label != null)
            Positioned(
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
            ),
        ],
      ),
    );
  }
}
