import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/notification.dart';

/// One notification. Unread ones are tinted green with a dot.
/// Swipe left to delete.
///
///   Row
///   ├─ round icon (order / promotion / info)
///   └─ Column: title ...... ●, message (2 lines), "il y a 5 min"
class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final double screenWidth;
  final double screenHeight;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismissed,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color iconColor;

    switch (notification.type) {
      case NotificationType.orderUpdate:
        icon = Icons.shopping_bag_outlined;
        iconColor = AppColors.primary;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer_outlined;
        iconColor = AppColors.success;
        break;
      case NotificationType.system:
        icon = Icons.info_outline;
        iconColor = AppColors.warning;
        break;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: screenWidth * 0.05),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
        ),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.error,
          size: screenWidth * 0.08,
        ),
      ),
      onDismissed: (direction) => onDismissed(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(bottom: screenHeight * 0.015),
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Theme.of(context).cardColor
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(screenWidth * 0.05),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: screenWidth * 0.025,
                offset: Offset(0, screenHeight * 0.006),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: screenWidth * 0.025,
                            height: screenWidth * 0.025,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: screenWidth * 0.036,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Text(
                      _formatTime(context, notification.timestamp),
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "À l'instant", "il y a 5 min", "il y a 3 h", else the time.
  String _formatTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final l = AppLocalizations.of(context)!;

    if (difference.inMinutes < 1) {
      return l.timeJustNow;
    } else if (difference.inMinutes < 60) {
      return l.timeMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l.timeHoursAgo(difference.inHours);
    } else {
      return DateFormat('HH:mm').format(timestamp);
    }
  }
}
