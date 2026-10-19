import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cmandili_mobile/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/notification.dart';
import 'notification_controller.dart';
import 'widgets/empty_notifications_view.dart';
import 'widgets/notification_card.dart';

/// The customer's notifications, grouped by day:
///
///   AppBar: "Notifications" ......... "Tout marquer comme lu"
///   _NotificationGroups
///     "Aujourd'hui"
///       NotificationCard …
///     "Hier"
///       NotificationCard …
///   or EmptyNotificationsView
///
/// Tap a card to mark it read, swipe it left to delete it. UI only: the
/// grouping and the actions live in [NotificationController].
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final notifications = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final groupedNotifications = controller.groupByDay(
      AppLocalizations.of(context)!,
      Localizations.localeOf(context).toString(),
    );

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
          if (controller.hasUnread)
            TextButton(
              onPressed: controller.markAllAsRead,
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
          : _NotificationGroups(
              groups: groupedNotifications,
              screenWidth: screenWidth,
              screenHeight: screenHeight,
              onTap: controller.open,
              onDismissed: controller.delete,
            ),
    );
  }
}

// ── Sections ──────────────────────────────────────────────────────────────────

/// One day title per group, then its NotificationCards.
class _NotificationGroups extends StatelessWidget {
  const _NotificationGroups({
    required this.groups,
    required this.screenWidth,
    required this.screenHeight,
    required this.onTap,
    required this.onDismissed,
  });

  final Map<String, List<AppNotification>> groups;
  final double screenWidth;
  final double screenHeight;
  final ValueChanged<AppNotification> onTap;
  final ValueChanged<AppNotification> onDismissed;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(screenWidth * 0.05),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups.entries.elementAt(index);
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
                onTap: () => onTap(notification),
                onDismissed: () => onDismissed(notification),
              ),
          ],
        );
      },
    );
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
