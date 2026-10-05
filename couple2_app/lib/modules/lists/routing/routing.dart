import 'package:go_router/go_router.dart';

import '../ui/pages/list_detail/list_detail_page.dart';
import '../ui/pages/lists/lists_page.dart';
import 'routes.dart';

final listsRoutes = [
  GoRoute(
    path: ListsRoutes.lists,
    builder: (_, __) => const ListsPage(),
  ),
  GoRoute(
    path: ListsRoutes.listDetail,
    builder: (_, state) =>
        ListDetailPage(listId: state.pathParameters['id']!),
  ),
];
