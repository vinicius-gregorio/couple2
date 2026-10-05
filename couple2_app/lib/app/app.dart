import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import '../modules/feed/data/feed_providers.dart';
import '../modules/mood/data/mood_providers.dart';
import '../modules/notifications/push_service.dart';
import '../modules/notifications/push_service_provider.dart';
import 'routing/router.dart';
import 'session_provider.dart';
export 'bootstrap.dart';

class CoupleApp extends ConsumerStatefulWidget {
  const CoupleApp({super.key});

  @override
  ConsumerState<CoupleApp> createState() => _CoupleAppState();
}

class _CoupleAppState extends ConsumerState<CoupleApp>
    with WidgetsBindingObserver {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _pushRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushServiceProvider).onForegroundMessage = _showForegroundSnack;
      _startPushIfPaired();
    });
  }

  void _showForegroundSnack(RemoteMessage message) {
    final body = message.notification?.body?.trim();
    if (body == null || body.isEmpty) return;
    final route = message.data['route'];
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Text(body),
          action: route is String && route.isNotEmpty
              ? SnackBarAction(
                  label: 'Ver',
                  onPressed: () => ref.read(routerProvider).push(route),
                )
              : null,
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).refresh();
      ref.invalidate(unreadCountProvider);
      ref.invalidate(feedPreviewProvider);
      ref.invalidate(currentMoodProvider);
      _startPushIfPaired();
    }
  }

  void _startPushIfPaired() {
    if (_pushRequested || !canRegisterPush) return;
    final session = ref.read(sessionProvider).asData?.value;
    if (session?.coupleId == null) return;
    _pushRequested = true;
    final router = ref.read(routerProvider);
    unawaited(ref.read(pushServiceProvider).ensureStarted(router));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      final before = previous?.asData?.value?.coupleId;
      final after = next.asData?.value?.coupleId;
      if (after == null) {
        _pushRequested = false;
        return;
      }
      if (after != before) {
        _pushRequested = false;
        _startPushIfPaired();
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
