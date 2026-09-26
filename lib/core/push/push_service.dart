import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/happy_hour/presentation/happy_hour_screen.dart';

/// Root navigator, so a tapped notification can open a screen from outside
/// the widget tree (MaterialApp.navigatorKey is set to this in main.dart).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ── Channel IDs ──────────────────────────────────────────────────────────────
//
// _v3: the previous 'cmandili_orders' channel was created WITHOUT playSound.
// On Android O+ that produces a permanently SILENT channel — it does not fall
// back to the default tone, and a channel's settings are immutable once the
// system has created it. Every status notification on this app has therefore
// been arriving with no sound. Bumping the id forces each device to create a
// fresh channel with audio enabled.
const String _kChannelId   = 'cmandili_orders_v3';
const String _kChannelName = 'Order updates';
const String _kChannelDesc = 'Notifications about your orders';

// High-priority channel for driver-arrival / on-the-way alerts.
//
// _v2: the original channel was created with a custom sound
// (RawResourceAndroidNotificationSound('new_order')) pointing at a raw
// resource that was never actually bundled into this app (it only exists
// in the driver app's project) -- every onTheWay/pickedUp push crashed with
// PlatformException(invalid_sound) instead of displaying. Android channels
// are immutable once created, so devices that already created the old
// channel would keep the broken config even after this fix; bumping the id
// makes every device create a fresh, correctly-configured channel instead.
// Urgent channel for driver on-the-way / arrival alerts. _v3 for the same
// immutability reason, and because it now carries a real bundled sound:
// android/app/src/main/res/raw/delivery_alert.mp3. The earlier version
// referenced 'new_order', a raw resource that only existed in the driver
// app — every push on that channel threw PlatformException(invalid_sound)
// and displayed nothing at all.
const String _kUrgentChannelId   = 'cmandili_orders_urgent_v3';
const String _kUrgentChannelName = 'Delivery alerts';
const String _kUrgentChannelDesc =
    'High-priority alerts when your driver is on the way';

// Promotions (Happy Hour started, ...). Its own channel so a customer can
// silence offers in Android settings without losing order updates. Default
// importance: it shows and sounds, but does not pop over what they are doing
// the way a driver-arrival alert does.
const String _kPromoChannelId   = 'cmandili_promos_v1';
const String _kPromoChannelName = 'Offres & Happy Hour';
const String _kPromoChannelDesc = 'Happy hours and deals from shops';

/// FCM topics for Happy Hour broadcasts, one per app language so the text
/// arrives in the language the customer reads the app in. The
/// push-happy-hour Edge Function sends one message to each.
const List<String> _kPromoLanguages = ['fr', 'ar', 'en'];
String _promoTopic(String lang) => 'happy_hour_$lang';

// Vibration strong enough to be felt in a pocket, matching the driver and
// partner apps.
final Int64List _kVibration = Int64List.fromList([0, 500, 300, 700, 300, 700]);

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
      // Tap on a notification we displayed ourselves (app in foreground).
      onDidReceiveNotificationResponse: (r) => _openFromPayload(r.payload),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Standard channel for order-lifecycle status updates.
    //
    // playSound and enableVibration MUST be explicit: a channel created
    // without them is created silent and stays that way forever.
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _kVibration,
    ));

    // Urgent channel for on-the-way / arrival alerts, with the bundled
    // delivery_alert sound so it is clearly louder and more distinctive than
    // an ordinary status ping.
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _kUrgentChannelId,
      _kUrgentChannelName,
      description: _kUrgentChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('delivery_alert'),
      enableVibration: true,
      vibrationPattern: _kVibration,
    ));

    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _kPromoChannelId,
      _kPromoChannelName,
      description: _kPromoChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Tap on a system notification while the app was in the background...
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
    // ...or one that launched the app from closed. The first screen is still
    // being built at this point, so wait a moment before navigating.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      Future.delayed(
        const Duration(milliseconds: 1200),
        () => _openFromData(initial.data),
      );
    }

    // Happy Hour broadcasts, in the language the app is set to. Works for
    // signed-out users too: topics do not need an account.
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('languageCode');
    final system = PlatformDispatcher.instance.locale.languageCode;
    await setPromoLanguage(
      saved ?? (_kPromoLanguages.contains(system) ? system : 'en'),
    );

    await _registerToken();
    _fcm.onTokenRefresh.listen((_) => _registerToken());

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) _registerToken();
    });
  }

  // ── Promotions topic ────────────────────────────────────────────────────

  String? _promoLanguage;

  /// Keeps this device subscribed to exactly one Happy Hour topic — the one
  /// for [languageCode] — so it never gets the same offer twice in two
  /// languages. Called at start-up and whenever the app language changes.
  Future<void> setPromoLanguage(String languageCode) async {
    final lang =
        _kPromoLanguages.contains(languageCode) ? languageCode : 'en';
    if (lang == _promoLanguage) return;
    _promoLanguage = lang;
    try {
      for (final other in _kPromoLanguages.where((l) => l != lang)) {
        await _fcm.unsubscribeFromTopic(_promoTopic(other));
      }
      await _fcm.subscribeToTopic(_promoTopic(lang));
    } catch (e) {
      // No Play Services / offline: retried on the next start or change.
      _promoLanguage = null;
      debugPrint('PushService: promo topic subscribe failed $e');
    }
  }

  // ── Notification taps ───────────────────────────────────────────────────

  void _openFromData(Map<String, dynamic> data) {
    if (data['type'] == 'happy_hour') {
      _openHappyHour(int.tryParse('${data['tab'] ?? 0}') ?? 0);
    }
  }

  void _openFromPayload(String? payload) {
    // Foreground notifications carry 'happy_hour:<tab>' as their payload.
    if (payload == null || !payload.startsWith('happy_hour')) return;
    _openHappyHour(int.tryParse(payload.split(':').last) ?? 0);
  }

  void _openHappyHour(int tab) {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => HappyHourScreen(initialTab: tab)),
    );
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

    // Happy Hour broadcast: normal promo notification, tappable into the deals.
    if (message.data['type'] == 'happy_hour') {
      _local.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _kPromoChannelId,
            _kPromoChannelName,
            channelDescription: _kPromoChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        payload: 'happy_hour:${message.data['tab'] ?? 0}',
      );
      return;
    }

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
              ? const RawResourceAndroidNotificationSound('delivery_alert')
              : null,
          // Alarm usage makes Android honour the sound even when the phone is
          // in Do Not Disturb, which is where a silent arrival alert hurts
          // most — the customer misses the driver at the door.
          audioAttributesUsage: isDriverAlert
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          enableVibration: true,
          vibrationPattern: _kVibration,
          // Wake the screen for a driver alert so it is seen from a pocket.
          fullScreenIntent: isDriverAlert,
          visibility: NotificationVisibility.public,
          category: isDriverAlert ? AndroidNotificationCategory.alarm : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: isDriverAlert ? 'delivery_alert.mp3' : null,
          // Critical alerts pierce silent mode. Requires the entitlement from
          // Apple; without it iOS falls back to a normal alert rather than
          // failing, so this is safe to request either way.
          interruptionLevel: isDriverAlert
              ? InterruptionLevel.critical
              : InterruptionLevel.active,
        ),
      ),
    );
  }
}
