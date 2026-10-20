import 'package:flutter/material.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/data/auth_repository.dart' show User;
import 'profile_avatar.dart';

/// The green top of the profile tab: avatar, name, email.
///
/// Returns a [SliverAppBar], so it goes in a [CustomScrollView]'s slivers.
class ProfileHeader extends StatelessWidget {
  final User? authUser;
  final ImageProvider? avatarImage;
  final bool isUploading;
  final VoidCallback onAvatarTap;
  final double screenWidth;
  final double screenHeight;

  const ProfileHeader({
    super.key,
    required this.authUser,
    required this.avatarImage,
    required this.isUploading,
    required this.onAvatarTap,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
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
                ProfileAvatar(
                  image: avatarImage,
                  isUploading: isUploading,
                  onTap: onAvatarTap,
                  screenWidth: screenWidth,
                ),
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
    );
  }
}
