import '../../modules/pairing/routing/routes.dart';

/// Pairing screens. Matched locations from GoRouter have no query string.
bool isPairingLocation(String matchedLocation) {
  return matchedLocation == PairingRoutes.hub ||
      matchedLocation.startsWith('${PairingRoutes.hub}/');
}

/// Sends an unpaired account into the pairing flow, and a paired account out
/// of it. Returns null to stay on [matchedLocation].
String? resolvePairingRedirect({
  required bool needsPairing,
  required String matchedLocation,
}) {
  final onPairing = isPairingLocation(matchedLocation);
  if (needsPairing) {
    return onPairing ? null : PairingRoutes.hub;
  }
  if (onPairing) return '/';
  return null;
}
