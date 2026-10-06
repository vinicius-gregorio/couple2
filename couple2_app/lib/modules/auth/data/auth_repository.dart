import 'dart:async';
import 'dart:convert';

import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/modules/notifications/data/device_token_store.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart'
    show ValueNotifier, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ValueNotifier] that still notifies when the logged-in flag does not change.
///
/// A session restored from storage never flips the flag to `true` unless we
/// publish it. Logout then sets `false` again and GoRouter would not refresh.
class AuthStateNotifier extends ValueNotifier<bool> {
  AuthStateNotifier() : super(false);

  void publish(bool loggedIn) {
    if (value == loggedIn) {
      notifyListeners();
      return;
    }
    value = loggedIn;
  }
}

abstract class IAuthRepository {
  Future<bool> isLoggedIn();
  Future<User> signInWithGoogle();
  Future<User> signInWithApple();
  Future<void> logOut();

  /// Notifier que emite quando o estado de autenticação muda
  ValueNotifier<bool> get authStateNotifier;

  /// Publishes [loggedIn] and always notifies, even if the value is unchanged.
  void publishLoggedIn(bool loggedIn);
}

class AuthRepository implements IAuthRepository {
  AuthRepository({required this.httpClient});
  static const _keyIsLoggedIn = 'is_logged_in';

  final ICPLHttpClient httpClient;

  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  /// Notifier para mudanças no estado de autenticação
  final AuthStateNotifier _authStateNotifier = AuthStateNotifier();

  @override
  ValueNotifier<bool> get authStateNotifier => _authStateNotifier;

  @override
  void publishLoggedIn(bool loggedIn) {
    _authStateNotifier.publish(loggedIn);
  }

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  @override
  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Firebase handles the OAuth popup directly.
      await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    } else {
      // Mobile/desktop: obtain a Google credential, exchange for a Firebase one.
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      GoogleSignInAccount? account = await googleSignIn
          .attemptLightweightAuthentication();
      account ??= await googleSignIn.authenticate();

      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      await _firebaseAuth.signInWithCredential(credential);
    }

    return _completeLogin();
  }

  @override
  Future<User> signInWithApple() async {
    final appleProvider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    if (kIsWeb) {
      await _firebaseAuth.signInWithPopup(appleProvider);
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Native Apple sign-in sheet on Apple platforms.
      await _firebaseAuth.signInWithProvider(appleProvider);
    } else {
      // Android falls back to Firebase's web OAuth flow.
      await _firebaseAuth.signInWithProvider(appleProvider);
    }

    return _completeLogin();
  }

  /// Exchanges the current Firebase ID token for an app JWT and persists it.
  Future<User> _completeLogin() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw Exception('Falha ao autenticar com o Firebase');
    }

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null) {
      throw Exception('Falha ao obter ID token do Firebase');
    }

    final response = await httpClient.post(
      '/auth/firebase',
      data: {'idToken': idToken},
    );

    final String accessToken = response.data['accessToken'];
    final User user = User.fromJson(response.data['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('user', jsonEncode(user.toJson()));
    await prefs.setBool(_keyIsLoggedIn, true);

    publishLoggedIn(true);

    return user;
  }

  @override
  Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(devicePushTokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        await httpClient.delete<void>('/devices/${Uri.encodeComponent(token)}');
      } catch (_) {
        // Logout still clears the local session if the device call fails.
      }
    }
    await prefs.clear();

    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Dev sessions are not signed into Firebase. Local logout still finishes.
    }

    publishLoggedIn(false);
  }
}
