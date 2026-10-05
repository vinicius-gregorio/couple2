import 'package:go_router/go_router.dart';

import '../ui/pages/date_plan_detail/date_plan_detail_page.dart';
import '../ui/pages/date_plan_form/date_plan_form_page.dart';
import '../ui/pages/date_plans/date_plans_page.dart';
import 'routes.dart';

final datePlanRoutes = [
  GoRoute(
    path: DatePlanRoutes.list,
    builder: (_, __) => const DatePlansPage(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (_, state) => DatePlanFormPage(
          sourceListItemId: state.uri.queryParameters['sourceListItemId'],
          initialTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: ':id',
        builder: (_, state) =>
            DatePlanDetailPage(id: state.pathParameters['id']!),
      ),
    ],
  ),
];
