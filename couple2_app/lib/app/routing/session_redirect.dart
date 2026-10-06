import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import 'auth_redirect.dart';
import 'pairing_redirect.dart';

/// True once we know whether this login still needs a partner.
///
/// A logged-in flag with a null session means `GET /auth/me` has not landed
/// yet. Hold the login screen instead of opening an empty Home.
bool sessionReadyForPairing(
  AsyncValue<Session?> session, {
  required bool? loggedIn,
}) {
  if (loggedIn != true) return true;
  if (session.hasError && !session.hasValue) return true;
  final value = session.asData?.value;
  if (value == null && !session.hasError) return false;
  return true;
}

/// Auth redirect, then the pairing gate.
///
/// Login with no `coupleId` and no `partnerId` goes to `/pairing`, never to
/// an empty Home. A paired visit to a pairing route goes Home.
String? resolveAppRedirect({
  required bool? loggedIn,
  required String matchedLocation,
  String? restoreLocation,
  required bool sessionReady,
  required bool needsPairing,
}) {
  final authTarget = resolveAuthRedirect(
    loggedIn: loggedIn,
    matchedLocation: matchedLocation,
    restoreLocation: restoreLocation,
  );

  if (loggedIn != true) return authTarget;

  if (!sessionReady) {
    if (matchedLocation.startsWith('/auth')) return null;
    return authTarget;
  }

  final next = authTarget ?? matchedLocation;
  final pairingTarget = resolvePairingRedirect(
    needsPairing: needsPairing,
    matchedLocation: next,
  );
  return pairingTarget ?? authTarget;
}
