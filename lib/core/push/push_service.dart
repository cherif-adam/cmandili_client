import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Channel IDs ──────────────────────────────────────────────────────────────
const String _kChannelId   = 'cmandili_orders';
const String _kChannelName = 'Order updates';
const String _kChannelDesc = 'Notifications about your orders';

// High-priority channel for driver-arrival / on-the-way alerts.
const String _kUrgentChannelId   = 'cmandili_orders_urgent';
const String _kUrgentChannelName = 'Delivery alerts';
const String _kUrgentChannelDesc =
    'High-priority alerts when your driver is on the way';

// ── Background handler ───────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android renders `notification`-payload pushes automatically via the
  // default channel declared in AndroidManifest. Nothing to do here for
  // standard status pushes.
  //
  // If you ever need data-only pushes on the client side, handle them here.
}

// ── PushService ──────────────────────────────────────────────────────────────

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Standard channel for order-lifecycle status updates.
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
    ));

    // Urgent channel for on-the-way / arrival alerts.
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _kUrgentChannelId,
      _kUrgentChannelName,
      description: _kUrgentChannelDesc,
      importance: Importance.max,
      playSound: true,
      // File: android/app/src/main/res/raw/new_order.mp3
      sound: RawResourceAndroidNotificationSound('new_order'),
    ));

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _registerToken();
    _fcm.onTokenRefresh.listen((_) => _registerToken());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _registerToken();
    });
  }

  // ── Token registration ──────────────────────────────────────────────────

  Future<void> _registerToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final token = await _fcm.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      }, onConflict: 'token');
    } catch (_) {}
  }

  // ── Foreground message handler ──────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    final status = message.data['status'] as String?;
    final title  = message.notification?.title ?? message.data['title'] as String?;
    final body   = message.notification?.body  ?? message.data['body']  as String?;
    if (title == null && body == null) return;

    // onTheWay / pickedUp get a heads-up banner with max importance so the
    // customer is aware that their driver is en route even if the app is open.
    final isDriverAlert = status == 'onTheWay' || status == 'pickedUp';

    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isDriverAlert ? _kUrgentChannelId : _kChannelId,
          isDriverAlert ? _kUrgentChannelName : _kChannelName,
          channelDescription: isDriverAlert ? _kUrgentChannelDesc : _kChannelDesc,
          importance: isDriverAlert ? Importance.max : Importance.high,
          priority:   isDriverAlert ? Priority.max  : Priority.high,
          playSound: true,
          sound: isDriverAlert
              ? const RawResourceAndroidNotificationSound('new_order')
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: isDriverAlert ? 'new_order.wav' : null,
        ),
      ),
    );
  }
}
