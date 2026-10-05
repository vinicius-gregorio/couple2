import 'package:couple2_app/app/di.dart';
import 'package:couple2_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> bootstrap() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await APPDI().init();
}
