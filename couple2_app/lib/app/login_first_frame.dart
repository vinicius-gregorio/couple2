import 'package:couple2_app/modules/auth/ui/widgets/google_logo.dart';
import 'package:flutter/services.dart';

import 'material_icons.dart';

/// Loads the login font files and Google mark while the HTML splash is up.
///
/// The engine already registered Plus Jakarta Sans from the font manifest.
/// Reading the files here keeps the splash until those bytes and the logo
/// are in memory. A failure does not throw: the splash still uncovers.
Future<void> warmLoginFirstFrame() async {
  try {
    await Future.wait<Object?>([
      rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
      rootBundle.load('assets/fonts/PlusJakartaSans-Medium.ttf'),
      rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
      rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
      kGoogleLogoLoader.loadBytes(null),
    ]);
    await warmMaterialIcons();
  } catch (_) {
    // A missing file must not leave the splash up after the first frame.
  }
}
