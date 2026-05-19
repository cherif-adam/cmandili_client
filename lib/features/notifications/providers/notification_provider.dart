import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

// Loads notifications from Supabase; falls back to empty list on error
final notificationsLoadProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repo = ref.read(notificationRepositoryProvider);
  final data = await repo.getUserNotifications();
  return data.map((json) => AppNotification(
    id: json['id'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    type: _parseType(json['type'] as String? ?? 'system'),
    timestamp: DateTime.parse(json['created_at'] as String),
    isRead: json['is_read'] as bool? ?? false,
    orderId: json['order_id'] as String?,
  )).toList();
});

NotificationType _parseType(String type) {
  switch (type) {
    case 'orderUpdate': return NotificationType.orderUpdate;
    case 'promotion': return NotificationType.promotion;
    default: return NotificationType.system;
  }
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final NotificationRepository _repo;

  NotificationNotifier(this._repo, List<AppNotification> initial) : super(initial);

  void markAsRead(String notificationId) {
    state = [
      for (final notification in state)
        if (notification.id == notificationId)
          notification.copyWith(isRead: true)
        else
          notification,
    ];
    _repo.markAsRead(notificationId);
  }

  void deleteNotification(String notificationId) {
    state = state.where((n) => n.id != notificationId).toList();
    _repo.deleteNotification(notificationId);
  }

  void markAllAsRead() {
    state = [
      for (final notification in state) notification.copyWith(isRead: true),
    ];
    for (final n in state) {
      _repo.markAsRead(n.id);
    }
  }

  void setNotifications(List<AppNotification> notifications) {
    state = notifications;
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  final repo = ref.read(notificationRepositoryProvider);
  final notifier = NotificationNotifier(repo, []);
  // Load from Supabase and populate state
  ref.listen(notificationsLoadProvider, (_, next) {
    next.whenData((list) => notifier.setNotifications(list));
  });
  return notifier;
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProvider);
  return notifications.where((n) => !n.isRead).length;
});
