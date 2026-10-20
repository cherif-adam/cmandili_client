import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/providers/localization_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/change_password/change_password_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bills/presentation/mes_factures/mes_factures_screen.dart';
import '../../../notifications/presentation/notification/notification_screen.dart';
import '../../../orders/presentation/order_history/order_history_screen.dart';
import '../edit_profile/edit_profile_screen.dart';
import '../help_support/help_support_screen.dart';
import '../payment_methods/payment_methods_screen.dart';
import '../saved_addresses/saved_addresses_screen.dart';
import 'profile_controller.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_menu_item.dart';
import 'widgets/profile_section_title.dart';
import 'widgets/profile_switch_item.dart';

/// The "Profil" tab, top to bottom:
///
///   ProfileHeader     green, avatar (tap to change), name, email
///   _AccountSection   orders, bills, edit profile, addresses, payment
///   _SettingsSection  notifications, bill reminders, language, theme,
///                     password, help
///   _LogoutSection
///
/// UI only: the bill reminders switch, the avatar upload, the logout and
/// the theme live in [ProfileController]; the image picker and the
/// navigation stay here.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// This tab's own controller (see [profileControllerProvider]).
  late final _provider = profileControllerProvider(Object());
  final _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localizationProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          ProfileHeader(
            authUser: authUser,
            avatarImage: controller.avatarImage(authUser),
            isUploading: state.isUploading,
            onAvatarTap: _pickAndUploadAvatar,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
          SliverPadding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _AccountSection(onOpen: _open),
                _SettingsSection(
                  onOpen: _open,
                  billRemindersEnabled: state.billRemindersEnabled,
                  onBillRemindersChanged: controller.setBillReminders,
                  languageName: ProfileController.languageName(locale.languageCode),
                  isDarkMode: themeMode == ThemeMode.dark,
                  onToggleTheme: controller.toggleTheme,
                ),
                _LogoutSection(onLogout: _logout),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
    await ref.read(_provider.notifier).logout();
  }

  Future<void> _pickAndUploadAvatar() async {
    final controller = ref.read(_provider.notifier);
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null || !mounted) return;

    final ok = await controller.uploadAvatar(File(picked.path));

    if (!mounted || ok) return;
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

// ── Sections ──────────────────────────────────────────────────────────────────

/// One profile menu row, sized to the screen like every row of this tab.
ProfileMenuItem _menuItem(
  BuildContext context, {
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  String? trailing,
  Color? color,
  bool showArrow = true,
}) {
  final size = MediaQuery.of(context).size;
  return ProfileMenuItem(
    icon: icon,
    title: title,
    onTap: onTap,
    trailing: trailing,
    textColor: color,
    iconColor: color,
    showArrow: showArrow,
    screenWidth: size.width,
    screenHeight: size.height,
  );
}

/// "Compte": orders, bills, edit profile, addresses, payment.
class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(title: l.account, screenWidth: size.width),
        _menuItem(
          context,
          icon: Icons.receipt_long_rounded,
          title: l.orderHistory,
          onTap: () => onOpen(const OrderHistoryScreen()),
        ),
        _menuItem(
          context,
          icon: Icons.electric_bolt_rounded,
          title: l.billsTitle,
          onTap: () => onOpen(const MesFacturesScreen()),
        ),
        _menuItem(
          context,
          icon: Icons.person_outline_rounded,
          title: l.editProfile,
          onTap: () => onOpen(const EditProfileScreen()),
        ),
        _menuItem(
          context,
          icon: Icons.location_on_outlined,
          title: l.savedAddresses,
          onTap: () => onOpen(const SavedAddressesScreen()),
        ),
        _menuItem(
          context,
          icon: Icons.payment_outlined,
          title: l.paymentMethods,
          onTap: () => onOpen(const PaymentMethodsScreen()),
        ),
        SizedBox(height: size.height * 0.03),
      ],
    );
  }
}

/// "Paramètres": notifications, bill reminders, language, theme, password,
/// help.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.onOpen,
    required this.billRemindersEnabled,
    required this.onBillRemindersChanged,
    required this.languageName,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final ValueChanged<Widget> onOpen;
  final bool billRemindersEnabled;
  final ValueChanged<bool> onBillRemindersChanged;
  final String languageName;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionTitle(title: l.settings, screenWidth: size.width),
        _menuItem(
          context,
          icon: Icons.notifications_outlined,
          title: l.notifications,
          onTap: () => onOpen(const NotificationScreen()),
        ),
        ProfileSwitchItem(
          icon: Icons.alarm_rounded,
          title: l.profileBillReminders,
          value: billRemindersEnabled,
          onChanged: onBillRemindersChanged,
          screenWidth: size.width,
          screenHeight: size.height,
        ),
        _menuItem(
          context,
          icon: Icons.language_outlined,
          title: l.language,
          trailing: languageName,
          onTap: () => showLanguagePickerSheet(context, size.width, size.height),
        ),
        _menuItem(
          context,
          icon: Icons.brightness_6_outlined,
          title: l.theme,
          trailing: isDarkMode ? l.darkMode : l.lightMode,
          onTap: onToggleTheme,
        ),
        _menuItem(
          context,
          icon: Icons.lock_outline_rounded,
          title: l.changePassword,
          onTap: () => onOpen(const ChangePasswordScreen()),
        ),
        _menuItem(
          context,
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          onTap: () => onOpen(const HelpSupportScreen()),
        ),
        SizedBox(height: size.height * 0.03),
      ],
    );
  }
}

/// "Déconnexion", then room for the floating menu bar.
class _LogoutSection extends StatelessWidget {
  const _LogoutSection({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _menuItem(
          context,
          icon: Icons.logout_rounded,
          title: AppLocalizations.of(context)!.logout,
          color: AppColors.error,
          showArrow: false,
          onTap: onLogout,
        ),
        SizedBox(height: size.height * 0.12),
      ],
    );
  }
}
