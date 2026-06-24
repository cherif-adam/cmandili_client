import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

const String _kPrefKey = 'bill_reminders_enabled';
const String _kChannelId = 'bill_reminders';
const String _kChannelName = 'Rappels de factures';
const String _kChannelDesc = 'Rappels mensuels pour vos factures récurrentes';

/// Schedules and manages monthly bill reminder local notifications.
/// Reminders fire ~28 days after a bill payment so the customer remembers
/// to pay the following month's bill.
class BillReminderService {
  BillReminderService._();
  static final BillReminderService instance = BillReminderService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.defaultImportance,
    ));
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, value);
    if (!value) {
      await _local.cancelAll();
    }
  }

  /// Schedules a reminder notification 28 days from now for [billType].
  /// Does nothing if the user has disabled reminders.
  Future<void> scheduleReminder({
    required String billType,
    required String billLabel,
  }) async {
    if (!await isEnabled()) return;
    await initialize();

    final fireAt = tz.TZDateTime.now(tz.local).add(const Duration(days: 28));

    // Use a stable notification ID derived from bill type so that a new
    // payment replaces the previous pending reminder for the same bill.
    final notifId = _stableId(billType);

    await _local.zonedSchedule(
      notifId,
      'Rappel facture $billLabel',
      'Votre facture $billLabel arrive peut-être à échéance. Payez-la facilement avec Amena !',
      fireAt,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _stableId(String billType) {
    const base = 9000;
    switch (billType) {
      case 'steg':   return base + 1;
      case 'sonede': return base + 2;
      case 'topnet': return base + 3;
      default:       return base + 4;
    }
  }
}
