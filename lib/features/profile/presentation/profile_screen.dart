import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/providers/localization_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart' show User;
import '../../auth/presentation/change_password_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bills/presentation/mes_factures/mes_factures_screen.dart';
import '../../bills/services/bill_reminder_service.dart';
import '../../notifications/presentation/notification/notification_screen.dart';
import '../../orders/presentation/order_history/order_history_screen.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'payment_methods/payment_methods_screen.dart';
import 'saved_addresses_screen.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_item.dart';
import 'widgets/profile_section_title.dart';
import 'widgets/profile_switch_item.dart';

/// The "Profil" tab, top to bottom:
///
///   ProfileHeader   green, avatar (tap to change), name, email
///   "Compte"        orders, bills, edit profile, addresses, payment
///   "Paramètres"    notifications, bill reminders, language, theme,
///                   password, help
///   Déconnexion
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileRepo = ProfileRepository();
  final _imagePicker = ImagePicker();
  bool _billRemindersEnabled = true;

  /// Tracks whether an upload is in progress so we can show the loading
  /// overlay and prevent double-taps.
  bool _isUploading = false;

  /// When non-null, this local file is displayed immediately after the user
  /// picks an image — before (and after) the upload completes — so the UI
  /// feels instant. It falls back gracefully to the remote URL on error.
  File? _localAvatar;

  @override
  void initState() {
    super.initState();
    BillReminderService.instance.isEnabled().then((v) {
      if (mounted) setState(() => _billRemindersEnabled = v);
    });
  }

  /// Really signs out, then lets main.dart show the login screen.
  ///
  /// This used to push a fresh AuthScreen and never call signOut: after the
  /// next sign-in the app switched to Home UNDERNEATH the pushed login
  /// screen, so the user was stuck on the login form.
  Future<void> _logout() async {
    // Back to the root route first (drop anything pushed over Home), so the
    // root is what changes to the login screen when the session ends.
    Navigator.of(context).popUntil((route) => route.isFirst);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }

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
          content: Text(AppLocalizations.of(context)!.profileUploadFailed),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Priority: local file (just picked) → remote URL from auth metadata → none.
  /// Null when the user has no picture: a person icon is drawn instead.
  ImageProvider? _avatarImage(User? authUser) {
    if (_localAvatar != null) return FileImage(_localAvatar!);
    final url = authUser?.photoURL;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  static String _languageName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final l = AppLocalizations.of(context)!;

    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localizationProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    ProfileMenuItem item({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
      String? trailing,
      Color? color,
      bool showArrow = true,
    }) =>
        ProfileMenuItem(
          icon: icon,
          title: title,
          onTap: onTap,
          trailing: trailing,
          textColor: color,
          iconColor: color,
          showArrow: showArrow,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          ProfileHeader(
            authUser: authUser,
            avatarImage: _avatarImage(authUser),
            isUploading: _isUploading,
            onAvatarTap: _pickAndUploadAvatar,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
          SliverPadding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Compte ─────────────────────────────────────────────────
                ProfileSectionTitle(title: l.account, screenWidth: screenWidth),
                item(
                  icon: Icons.receipt_long_rounded,
                  title: l.orderHistory,
                  onTap: () => _open(const OrderHistoryScreen()),
                ),
                item(
                  icon: Icons.electric_bolt_rounded,
                  title: l.billsTitle,
                  onTap: () => _open(const MesFacturesScreen()),
                ),
                item(
                  icon: Icons.person_outline_rounded,
                  title: l.editProfile,
                  onTap: () => _open(const EditProfileScreen()),
                ),
                item(
                  icon: Icons.location_on_outlined,
                  title: l.savedAddresses,
                  onTap: () => _open(const SavedAddressesScreen()),
                ),
                item(
                  icon: Icons.payment_outlined,
                  title: l.paymentMethods,
                  onTap: () => _open(const PaymentMethodsScreen()),
                ),
                SizedBox(height: screenHeight * 0.03),

                // ── Paramètres ─────────────────────────────────────────────
                ProfileSectionTitle(title: l.settings, screenWidth: screenWidth),
                item(
                  icon: Icons.notifications_outlined,
                  title: l.notifications,
                  onTap: () => _open(const NotificationScreen()),
                ),
                ProfileSwitchItem(
                  icon: Icons.alarm_rounded,
                  title: l.profileBillReminders,
                  value: _billRemindersEnabled,
                  onChanged: (v) async {
                    setState(() => _billRemindersEnabled = v);
                    await BillReminderService.instance.setEnabled(v);
                  },
                  screenWidth: screenWidth,
                  screenHeight: screenHeight,
                ),
                item(
                  icon: Icons.language_outlined,
                  title: l.language,
                  trailing: _languageName(locale.languageCode),
                  onTap: () => showLanguagePickerSheet(
                      context, screenWidth, screenHeight),
                ),
                item(
                  icon: Icons.brightness_6_outlined,
                  title: l.theme,
                  trailing: themeMode == ThemeMode.dark ? l.darkMode : l.lightMode,
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                ),
                item(
                  icon: Icons.lock_outline_rounded,
                  title: l.changePassword,
                  onTap: () => _open(const ChangePasswordScreen()),
                ),
                item(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => _open(const HelpSupportScreen()),
                ),
                SizedBox(height: screenHeight * 0.03),

                // ── Déconnexion ────────────────────────────────────────────
                item(
                  icon: Icons.logout_rounded,
                  title: l.logout,
                  color: AppColors.error,
                  showArrow: false,
                  onTap: _logout,
                ),
                SizedBox(height: screenHeight * 0.12),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
