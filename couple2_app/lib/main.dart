import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'modules/notifications/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  if (canRegisterPush) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: CoupleApp()));
}
