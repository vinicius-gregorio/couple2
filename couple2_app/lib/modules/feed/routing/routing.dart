import 'package:go_router/go_router.dart';

import '../ui/pages/feed/feed_page.dart';
import 'routes.dart';

final feedRoutes = [
  GoRoute(
    path: FeedRoutes.feed,
    builder: (_, __) => const FeedPage(),
  ),
];
