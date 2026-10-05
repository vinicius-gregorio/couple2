import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../core/core.dart';
import 'lists_repository.dart';

final listsRepositoryProvider = Provider<IListsRepository>((ref) {
  return ListsRepository(httpClient: GetIt.I<ICPLHttpClient>());
});
