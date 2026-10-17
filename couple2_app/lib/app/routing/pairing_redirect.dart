import '../../modules/pairing/routing/routes.dart';

/// Hash URLs can report `/` while the route lives in the fragment.
String routeLocation({
  required String matchedLocation,
  required String fragment,
}) {
  if (matchedLocation.length > 1) return matchedLocation;
  final path = fragment.split('?').first;
  if (path.startsWith('/')) return path;
  return matchedLocation;
}

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
