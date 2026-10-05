/// Opens the screen named in an FCM `data.route` payload.
/// Used for a tap while the app is backgrounded and for a cold start.
void followPushRoute(
  Map<String, dynamic> data,
  void Function(String route) push,
) {
  final route = data['route'];
  if (route is String && route.isNotEmpty) {
    push(route);
  }
}
