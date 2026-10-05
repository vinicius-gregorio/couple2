import 'package:go_router/go_router.dart';

import '../ui/pages/couple_settings/couple_settings_page.dart';
import '../ui/pages/important_dates/important_dates_page.dart';
import 'routes.dart';

final coupleRoutes = [
  GoRoute(
    path: CoupleRoutes.settings,
    builder: (_, __) => const CoupleSettingsPage(),
  ),
  GoRoute(
    path: CoupleRoutes.dates,
    builder: (_, __) => const ImportantDatesPage(),
  ),
];
