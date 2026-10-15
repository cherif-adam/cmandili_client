import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../core/theme/app_colors.dart';
import '../../notifications/data/models/notification.dart';
import '../../notifications/providers/notification_provider.dart';
import 'widgets/empty_notifications_view.dart';
import 'widgets/notification_card.dart';

/// The customer's notifications, grouped by day:
///
///   AppBar: "Notifications" ......... "Tout marquer comme lu"
///   "Aujourd'hui"
///     NotificationCard …
///   "Hier"
///     NotificationCard …
///   or EmptyNotificationsView
///
/// Tap a card to mark it read, swipe it left to delete it.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final notifications = ref.watch(notificationProvider);
    final groupedNotifications = _groupByDate(context, notifications);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: screenWidth * 0.05,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              child: Text(
                AppLocalizations.of(context)!.markAllRead,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? EmptyNotificationsView(screenWidth: screenWidth, screenHeight: screenHeight)
          : ListView.builder(
              padding: EdgeInsets.all(screenWidth * 0.05),
              itemCount: groupedNotifications.length,
              itemBuilder: (context, index) {
                final entry = groupedNotifications.entries.elementAt(index);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DayTitle(
                      label: entry.key,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    for (final notification in entry.value)
                      NotificationCard(
                        notification: notification,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        onTap: () {
                          if (!notification.isRead) {
                            ref
                                .read(notificationProvider.notifier)
                                .markAsRead(notification.id);
                          }
                        },
                        onDismissed: () {
                          ref
                              .read(notificationProvider.notifier)
                              .deleteNotification(notification.id);
                        },
                      ),
                  ],
                );
              },
            ),
    );
  }

  /// "Aujourd'hui", "Hier", the weekday for this week, else the date.
  Map<String, List<AppNotification>> _groupByDate(
      BuildContext context, List<AppNotification> notifications) {
    final Map<String, List<AppNotification>> grouped = {};
    final now = DateTime.now();
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    for (final notification in notifications) {
      String dateLabel;
      final difference = now.difference(notification.timestamp);

      if (difference.inDays == 0) {
        dateLabel = l.today;
      } else if (difference.inDays == 1) {
        dateLabel = l.yesterday;
      } else if (difference.inDays < 7) {
        dateLabel = DateFormat('EEEE', locale).format(notification.timestamp);
      } else {
        dateLabel =
            DateFormat('d MMM yyyy', locale).format(notification.timestamp);
      }

      grouped.putIfAbsent(dateLabel, () => []).add(notification);
    }

    return grouped;
  }
}

/// The grey day title above a group of notifications.
class _DayTitle extends StatelessWidget {
  final String label;
  final double screenWidth;
  final double screenHeight;

  const _DayTitle({
    required this.label,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * 0.015,
        horizontal: screenWidth * 0.02,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: screenWidth * 0.038,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
