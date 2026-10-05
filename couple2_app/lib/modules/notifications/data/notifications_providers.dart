import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../core/core.dart';
import 'notifications_repository.dart';

final notificationsRepositoryProvider = Provider<INotificationsRepository>((ref) {
  return NotificationsRepository(httpClient: GetIt.I<ICPLHttpClient>());
});
