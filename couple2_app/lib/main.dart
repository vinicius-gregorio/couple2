import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'app/login_first_frame.dart';
import 'app/splash_gate.dart';
import 'app/web_splash.dart';
import 'modules/notifications/push_service.dart';

void main() async {
  // Hash URLs (`/#/question`) are what refresh restores. `push` is imperative
  // and, by default, does not write the browser URL.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  setUrlStrategy(HashUrlStrategy());
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  if (canRegisterPush) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: CoupleApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      dismissSplashWhenReady(
        assetsReady: warmLoginFirstFrame(),
        removeSplash: removeWebSplash,
        afterReady: _nextFrame,
      ),
    );
  });
}

/// One more frame so the warmed logo and font are in the tree before the
/// HTML splash uncovers them.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) completer.complete();
  });
  WidgetsBinding.instance.scheduleFrame();
  return completer.future;
}
