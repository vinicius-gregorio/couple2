import '../../modules/auth/routing/routes.dart';
import 'routes.dart';

/// Where to send the user, or null to stay on [matchedLocation].
///
/// [loggedIn] is null while the stored session is still being read. Returning
/// null in that window keeps the browser route so a refresh can restore it
/// after auth resolves.
String? resolveAuthRedirect({
  required bool? loggedIn,
  required String matchedLocation,
  String? restoreLocation,
}) {
  final atLogin = matchedLocation.startsWith('/auth');
  if (loggedIn == null) return null;
  if (!loggedIn) {
    return atLogin ? null : AuthRoutes.login;
  }
  if (atLogin) {
    final restore = restoreLocation;
    if (restore != null &&
        restore.startsWith('/') &&
        !restore.startsWith('/auth')) {
      return restore;
    }
    return APPRoutes.home;
  }
  return null;
}

/// Route to reopen after login. Home and the auth screens are not remembered.
String? locationToRestore(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path.isEmpty || path == APPRoutes.home || path.startsWith('/auth')) {
    return null;
  }
  return location;
}
