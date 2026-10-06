import 'package:couple2_app/app/di.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/firebase_options.dart';
import 'package:couple2_app/modules/auth/data/auth_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

Future<void> bootstrap() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await APPDI().init();
  // After Firebase is ready and before the widget tree reads the session.
  // A return from Google exchanges the ID token here, then auth bootstrap
  // sees the stored login.
  if (kIsWeb) {
    await AuthRepository(
      httpClient: GetIt.I<ICPLHttpClient>(),
    ).completeRedirectSignIn();
  }
}
