import 'package:go_router/go_router.dart';

import '../ui/pages/mood_history/mood_history_page.dart';
import '../ui/pages/nudges/nudges_page.dart';
import 'routes.dart';

final moodRoutes = [
  GoRoute(
    path: MoodRoutes.history,
    builder: (_, __) => const MoodHistoryPage(),
  ),
  GoRoute(path: MoodRoutes.nudges, builder: (_, __) => const NudgesPage()),
];
