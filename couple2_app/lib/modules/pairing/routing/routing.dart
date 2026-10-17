import 'package:go_router/go_router.dart';

import '../ui/pages/enter_code/enter_code_page.dart';
import '../ui/pages/pairing_code/pairing_code_page.dart';
import '../ui/pages/waiting/waiting_page.dart';
import 'routes.dart';

final pairingRoutes = [
  GoRoute(
    path: PairingRoutes.hub,
    pageBuilder: (_, state) => NoTransitionPage(
      key: state.pageKey,
      child: const PairingCodePage(),
    ),
  ),
  GoRoute(
    path: PairingRoutes.enter,
    pageBuilder: (_, state) => NoTransitionPage(
      key: state.pageKey,
      child: const EnterCodePage(),
    ),
  ),
  GoRoute(
    path: PairingRoutes.waiting,
    pageBuilder: (_, state) => NoTransitionPage(
      key: state.pageKey,
      child: const WaitingPage(),
    ),
  ),
];
