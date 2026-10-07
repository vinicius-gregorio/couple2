import 'package:firebase_auth/firebase_auth.dart';

/// The browser is leaving for Google. The app session is created when the
/// page loads again and [runGoogleRedirectBootstrap] exchanges the ID token.
class GoogleRedirectInProgress implements Exception {
  const GoogleRedirectInProgress();
}

/// A Google redirect that failed before Flutter could show UI.
///
/// [take] hands the error to the login screen so it is not dropped.
class PendingGoogleAuthError {
  static Object? _error;

  static void report(Object error) {
    _error = error;
  }

  static Object? take() {
    final error = _error;
    _error = null;
    return error;
  }

  static void reset() => _error = null;
}

/// Web Google sign-in always tries redirect first.
///
/// Popup runs only when redirect throws before navigation. If redirect starts
/// and Firebase has no user yet, this throws [GoogleRedirectInProgress]: the
/// page is navigating away, and [runGoogleRedirectBootstrap] finishes login
/// on the way back. Popup errors propagate so the Firebase code stays visible.
Future<void> signInWithGoogleOnWeb({
  required Future<void> Function() signInWithRedirect,
  required Future<void> Function() signInWithPopup,
  required bool Function() hasCurrentUser,
}) async {
  try {
    await signInWithRedirect();
  } catch (redirectError) {
    try {
      await signInWithPopup();
    } catch (popupError) {
      throw _visibleAuthError(redirectError, popupError);
    }
    return;
  }
  if (!hasCurrentUser()) {
    throw const GoogleRedirectInProgress();
  }
}

/// Prefer a [FirebaseAuthException] so the login screen can show its code.
Object _visibleAuthError(Object redirectError, Object popupError) {
  if (popupError is FirebaseAuthException) return popupError;
  if (redirectError is FirebaseAuthException) return redirectError;
  return popupError;
}

/// A redirect return has a Firebase user when either check is set.
///
/// [getRedirectResult] is empty on some mobile browsers even after the
/// handler has signed the user in. [currentUser] is enough to exchange
/// the ID token; neither means this page load was not a redirect return.
bool redirectReturnedFirebaseUser({
  required bool redirectResultHasUser,
  required bool hasCurrentUser,
}) {
  return redirectResultHasUser || hasCurrentUser;
}

/// Exchanges a returning Google redirect for an app session.
///
/// Returns whether [completeLogin] ran. Errors from either step propagate.
Future<bool> completeGoogleRedirect({
  required Future<bool> Function() hasRedirectUser,
  required Future<void> Function() completeLogin,
}) async {
  if (!await hasRedirectUser()) return false;
  await completeLogin();
  return true;
}

/// Runs [completeGoogleRedirect] once per page load.
///
/// A failure is reported through [onError] so startup can continue and the
/// login screen can show the Firebase code. The error is not discarded.
Future<void> runGoogleRedirectBootstrap({
  required Future<bool> Function() hasRedirectUser,
  required Future<void> Function() completeLogin,
  required void Function(Object error) onError,
}) async {
  try {
    await completeGoogleRedirect(
      hasRedirectUser: hasRedirectUser,
      completeLogin: completeLogin,
    );
  } catch (error) {
    onError(error);
  }
}
