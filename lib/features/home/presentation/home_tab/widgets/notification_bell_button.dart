import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../notifications/presentation/notification/notification_screen.dart';
import '../../../../notifications/providers/notification_provider.dart';

/// The bell in the home header, with a red badge for unread notifications.
/// Tapping it opens the notifications screen.
class NotificationBellButton extends ConsumerWidget {
  final double screenWidth;
  final double screenHeight;

  const NotificationBellButton({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: screenWidth * 0.06,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          if (unread > 0)
            Positioned(
              top: screenHeight * 0.008,
              right: screenWidth * 0.02,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.01),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: screenWidth * 0.045,
                  minHeight: screenWidth * 0.045,
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
