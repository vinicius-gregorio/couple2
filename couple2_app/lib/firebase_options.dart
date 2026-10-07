// Firebase web app for project `couple42-f87b6` (Hosting + Google sign-in).
//
// TODO(deployer): Android and iOS below still point at the old project
// `couple42-27692` (project number 1002990038711). Prod web and the Google
// provider are `couple42-f87b6`. Do not ship mobile against these values.
// Replace them with the couple42-f87b6 `google-services.json` and
// `GoogleService-Info.plist` from the Firebase console. Those files are not
// in the repo, and the f87b6 mobile apiKey/appId were not provided, so the
// mobile entries were left unchanged on purpose.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD9P9F1D4JEotkekw9UFFg5faj0bTIH8So',
    appId: '1:921169930113:web:5976bc9325ca7d48712a80',
    messagingSenderId: '921169930113',
    projectId: 'couple42-f87b6',
    // Must match Hosting. firebaseapp.com is a different site, so mobile
    // browsers partition its storage: signInWithRedirect dies in the handler
    // (second createAuthUri net::ERR_FAILED) and returns to login before Google.
    authDomain: 'couple42-f87b6.web.app',
    storageBucket: 'couple42-f87b6.firebasestorage.app',
    measurementId: 'G-E6L527GRRE',
  );

  // TODO(deployer): still couple42-27692. Needs the f87b6 Android app config.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqVrlddtI55e3WLj4I9IlJYvSfrhYwbc0',
    appId: '1:1002990038711:android:a7a9187ea54874417b6732',
    messagingSenderId: '1002990038711',
    projectId: 'couple42-27692',
    storageBucket: 'couple42-27692.firebasestorage.app',
  );

  // TODO(deployer): still couple42-27692. Needs the f87b6 iOS app config.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBxw45vltEZy8qiB0HJuzuDHvffgwErRCI',
    appId: '1:1002990038711:ios:22730ea031dbaebf7b6732',
    messagingSenderId: '1002990038711',
    projectId: 'couple42-27692',
    storageBucket: 'couple42-27692.firebasestorage.app',
    iosBundleId: 'com.example.couple2App',
  );
}
