import 'package:get_it/get_it.dart';

import '../core/core.dart';

class APPDI {
  // static final someService = Provider<SomeService>((ref) {
  //   return SomeServiceImpl();
  // });

  Future<void> init() async {
    GetIt.I.registerSingleton<ICPLHttpClient>(
      DioClient(baseUrl: 'http://localhost:3000'),
    );
  }
}
