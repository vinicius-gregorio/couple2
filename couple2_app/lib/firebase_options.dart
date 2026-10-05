// File generated/maintained for FlutterFire — Firebase project `couple42-27692`.
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
    apiKey: 'AIzaSyCec6nKj1UhIA8oJarzXaAVg7yGFcNm8SA',
    appId: '1:1002990038711:web:27aaf475790557687b6732',
    messagingSenderId: '1002990038711',
    projectId: 'couple42-27692',
    authDomain: 'couple42-27692.firebaseapp.com',
    storageBucket: 'couple42-27692.firebasestorage.app',
    measurementId: 'G-PV1CW9BNTH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqVrlddtI55e3WLj4I9IlJYvSfrhYwbc0',
    appId: '1:1002990038711:android:a7a9187ea54874417b6732',
    messagingSenderId: '1002990038711',
    projectId: 'couple42-27692',
    storageBucket: 'couple42-27692.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBxw45vltEZy8qiB0HJuzuDHvffgwErRCI',
    appId: '1:1002990038711:ios:22730ea031dbaebf7b6732',
    messagingSenderId: '1002990038711',
    projectId: 'couple42-27692',
    storageBucket: 'couple42-27692.firebasestorage.app',
    iosBundleId: 'com.example.couple2App',
  );
}
