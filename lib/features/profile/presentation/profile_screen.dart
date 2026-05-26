import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart' show User;
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';
import '../../../core/providers/localization_provider.dart';
import '../../../core/providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../../orders/presentation/order_history_screen.dart';
import 'saved_addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'help_support_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileRepo = ProfileRepository();
  final _imagePicker = ImagePicker();

  /// Tracks whether an upload is in progress so we can show the loading
  /// overlay and prevent double-taps.
  bool _isUploading = false;

  /// When non-null, this local file is displayed immediately after the user
  /// picks an image — before (and after) the upload completes — so the UI
  /// feels instant. It falls back gracefully to the remote URL on error.
  File? _localAvatar;

  // ── Avatar pick & upload ──────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);

    // Show the chosen image immediately — optimistic UI.
    setState(() {
      _localAvatar = file;
      _isUploading = true;
    });

    final url = await _profileRepo.uploadProfilePicture(file);

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (url == null) {
      // Revert optimistic image on failure.
      setState(() => _localAvatar = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Échec du chargement. Veuillez réessayer.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Priority: local file (just picked) → remote URL from auth metadata → fallback.
  ImageProvider _avatarImageProvider(User? authUser) {
    if (_localAvatar != null) return FileImage(_localAvatar!);
    final url = authUser?.photoURL;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return const NetworkImage(
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localizationProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: screenHeight * 0.25,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAvatar(authUser, screenWidth),
                      SizedBox(height: screenHeight * 0.02),
                      Text(
                        authUser?.displayName ??
                            authUser?.email?.split('@').first ??
                            AppLocalizations.of(context)!.user,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        authUser?.email ?? '',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader(
                    context, AppLocalizations.of(context)!.account, screenWidth),
                _buildProfileItem(
                  context,
                  icon: Icons.receipt_long_rounded,
                  title: AppLocalizations.of(context)!.orderHistory,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: AppLocalizations.of(context)!.editProfile,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.location_on_outlined,
                  title: AppLocalizations.of(context)!.savedAddresses,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.payment_outlined,
                  title: AppLocalizations.of(context)!.paymentMethods,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.03),
                _buildSectionHeader(
                    context, AppLocalizations.of(context)!.settings, screenWidth),
                _buildProfileItem(
                  context,
                  icon: Icons.notifications_outlined,
                  title: AppLocalizations.of(context)!.notifications,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.language_outlined,
                  title: AppLocalizations.of(context)!.language,
                  trailing: _getLanguageName(locale.languageCode),
                  onTap: () => _showLanguageBottomSheet(
                      context, screenWidth, screenHeight),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.brightness_6_outlined,
                  title: AppLocalizations.of(context)!.theme,
                  trailing: themeMode == ThemeMode.dark
                      ? AppLocalizations.of(context)!.darkMode
                      : AppLocalizations.of(context)!.lightMode,
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                _buildProfileItem(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.03),
                _buildProfileItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: AppLocalizations.of(context)!.logout,
                  textColor: AppColors.error,
                  iconColor: AppColors.error,
                  showArrow: false,
                  onTap: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  ),
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                SizedBox(height: screenHeight * 0.12),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar widget ─────────────────────────────────────────────────────────

  Widget _buildAvatar(User? authUser, double screenWidth) {
    final radius = screenWidth * 0.125;
    // The badge sits at the bottom-right edge of the circle.
    final badgeSize = screenWidth * 0.082;
    // The outer container adds a semi-transparent ring around the circle.
    final outerSize = radius * 2 + screenWidth * 0.04;

    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUploadAvatar,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Outer glow ring ─────────────────────────────────────────────
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
            ),

            // ── Avatar circle ───────────────────────────────────────────────
            CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white,
              backgroundImage: _avatarImageProvider(authUser),
            ),

            // ── Upload loading overlay ──────────────────────────────────────
            if (_isUploading)
              Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.45),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),

            // ── Camera edit badge ───────────────────────────────────────────
            // Hidden during upload to avoid visual clutter.
            if (!_isUploading)
              Positioned(
                bottom: screenWidth * 0.005,
                right: screenWidth * 0.005,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: badgeSize * 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getLanguageName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }

  void _showLanguageBottomSheet(
      BuildContext context, double screenWidth, double screenHeight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(screenWidth * 0.06),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(screenWidth * 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.language,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.055,
                  ),
            ),
            SizedBox(height: screenHeight * 0.03),
            _buildLanguageOption(context, 'English', 'en', screenWidth),
            _buildLanguageOption(context, 'العربية', 'ar', screenWidth),
            _buildLanguageOption(context, 'Français', 'fr', screenWidth),
            SizedBox(height: screenHeight * 0.03),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, String name, String code, double screenWidth) {
    final isSelected = ref.watch(localizationProvider).languageCode == code;
    return ListTile(
      title: Text(name, style: TextStyle(fontSize: screenWidth * 0.04)),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.primary, size: screenWidth * 0.06)
          : null,
      onTap: () {
        ref.read(localizationProvider.notifier).setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: screenWidth * 0.04,
        left: screenWidth * 0.01,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
    String? trailing,
    Color? textColor,
    Color? iconColor,
    bool showArrow = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.05),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: screenWidth * 0.025,
            offset: Offset(0, screenHeight * 0.006),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.025),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? AppColors.primary,
                    size: screenWidth * 0.055,
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: textColor ??
                          Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.6),
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                if (showArrow) ...[
                  SizedBox(width: screenWidth * 0.02),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: screenWidth * 0.04,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
