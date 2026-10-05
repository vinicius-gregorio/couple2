import 'package:go_router/go_router.dart';

import '../ui/pages/notification_preferences/notification_preferences_page.dart';
import 'routes.dart';

final notificationRoutes = [
  GoRoute(
    path: NotificationRoutes.preferences,
    builder: (_, __) => const NotificationPreferencesPage(),
  ),
];
