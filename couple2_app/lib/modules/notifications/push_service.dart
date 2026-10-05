import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/device_token_store.dart';
import 'data/notifications_repository.dart';
import 'domain/push_route.dart';

const coupleActivityChannelId = 'couple_activity';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS shows `notification` payloads. The tap is handled on resume via
  // getInitialMessage / onMessageOpenedApp.
}

/// Asks for push permission only after the couple exists, then keeps the
/// device token registered. A tap opens `data.route`.
class PushService {
  PushService({
    required INotificationsRepository repository,
    this.onActivity,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _repository = repository,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final INotificationsRepository _repository;
  final void Function()? onActivity;

  /// Foreground FCM message. The app shows a snackbar from this callback.
  void Function(RemoteMessage message)? onForegroundMessage;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _started = false;
  GoRouter? _router;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  Future<void> ensureStarted(GoRouter router) async {
    _router = router;
    if (_started || !canRegisterPush) return;
    _started = true;

    await _prepareLocalNotifications();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      followPushRoute(Map<String, dynamic>.from(initial.data), (route) {
        router.push(route);
      });
    }

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final current = _router;
      if (current == null) return;
      followPushRoute(Map<String, dynamic>.from(message.data), (route) {
        current.push(route);
      });
      onActivity?.call();
    });

    _messageSub = FirebaseMessaging.onMessage.listen((message) async {
      onForegroundMessage?.call(message);
      await _showForeground(message);
      onActivity?.call();
    });

    _refreshSub = _messaging.onTokenRefresh.listen((token) {
      unawaited(_register(token));
    });

    final token = await _messaging.getToken();
    if (token != null) await _register(token);
  }

  /// Drops listeners so the next account can register after pairing.
  /// Does not clear prefs; logout deletes the token first.
  Future<void> stop() async {
    await _refreshSub?.cancel();
    await _openedSub?.cancel();
    await _messageSub?.cancel();
    _refreshSub = null;
    _openedSub = null;
    _messageSub = null;
    _started = false;
  }

  Future<void> _register(String token) async {
    final platform = _platformName();
    if (platform == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(devicePushTokenKey, token);
    await _repository.registerDevice(
      token: token,
      platform: platform,
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }

  Future<void> _prepareLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        final router = _router;
        if (route == null || route.isEmpty || router == null) return;
        router.push(route);
      },
    );
    const channel = AndroidNotificationChannel(
      coupleActivityChannelId,
      'Atividade do casal',
      description: 'Listas e datas importantes',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    if (notification == null) return;
    final route = message.data['route'];
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          coupleActivityChannelId,
          'Atividade do casal',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: route is String ? route : null,
    );
  }

  String? _platformName() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return null;
    }
  }
}

bool get canRegisterPush {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
