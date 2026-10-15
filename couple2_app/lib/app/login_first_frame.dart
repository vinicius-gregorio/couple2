import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/auth/ui/widgets/google_logo.dart';
import 'package:google_fonts/google_fonts.dart';

/// Starts the login font and Google mark while the HTML splash is still up.
///
/// Call this after the first frame so the asset bundle can serve the mark and
/// [GoogleFonts.pendingFonts] can finish Plus Jakarta Sans. A failed fetch
/// does not throw: the splash timeout still uncovers the screen.
Future<void> warmLoginFirstFrame() async {
  try {
    final theme = lightTextTheme();
    final button = appButtonTextStyle();
    await GoogleFonts.pendingFonts([
      theme.headlineMedium,
      theme.bodyMedium,
      theme.bodyLarge,
      button,
    ]);
  } catch (_) {
    // The splash must not wait on a font host that never answers.
  }
  try {
    await kGoogleLogoLoader.loadBytes(null);
  } catch (_) {
    // The button paints its own copy of the inlined mark if this misses.
  }
}
