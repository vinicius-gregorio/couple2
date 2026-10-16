import 'package:flutter/services.dart';

import 'material_icons_check.dart';

/// Loads Material Icons before the HTML splash uncovers the first screen.
///
/// The family is declared with `uses-material-design`. Web builds keep the
/// whole file (`--no-tree-shake-icons`) so a dynamic [IconData] is not a box.
Future<void> warmMaterialIcons() async {
  try {
    final data = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(data));
    await loader.load();
  } catch (_) {
    // The engine may already have registered the family from the manifest.
  }
  await confirmMaterialIconsLoaded();
}
