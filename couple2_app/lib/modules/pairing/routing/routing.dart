import 'package:go_router/go_router.dart';

import '../ui/pages/enter_code/enter_code_page.dart';
import '../ui/pages/pairing_code/pairing_code_page.dart';
import '../ui/pages/waiting/waiting_page.dart';
import 'routes.dart';

final pairingRoutes = [
  GoRoute(path: PairingRoutes.hub, builder: (_, __) => const PairingCodePage()),
  GoRoute(path: PairingRoutes.enter, builder: (_, __) => const EnterCodePage()),
  GoRoute(path: PairingRoutes.waiting, builder: (_, __) => const WaitingPage()),
];
