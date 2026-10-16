import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'material_icons_check.dart';

/// Icons the web release must keep after tree shaking.
///
/// `flutter build web` subsets MaterialIcons. A glyph survives only when a
/// const [IconData] is referenced from code that runs. This list is that
/// reference. Do not pass `--no-tree-shake-icons`.
const keptMaterialIcons = <IconData>[
  Icons.chevron_right,
  Icons.add,
  Icons.schedule,
  Icons.event_available_outlined,
  Icons.copy,
  Icons.share,
  Icons.refresh,
  Icons.logout,
  Icons.check_circle,
  Icons.circle,
  Icons.lock_outline,
  Icons.delete_outline,
  Icons.link,
  Icons.shopping_cart,
  Icons.movie,
  Icons.flag,
  Icons.flight,
  Icons.card_giftcard,
  Icons.list,
  Icons.history,
  Icons.person,
  Icons.favorite,
  Icons.cloud_off_outlined,
  Icons.inbox_outlined,
  Icons.edit_outlined,
  Icons.apple,
  Icons.login,
  Icons.notifications_outlined,
  Icons.tune,
  Icons.playlist_add,
  Icons.add_task,
  Icons.check_circle_outline,
  Icons.cake_outlined,
  Icons.favorite_outline,
  Icons.question_answer_outlined,
  Icons.lock_open,
  Icons.sentiment_satisfied_alt_outlined,
  Icons.favorite_border,
  Icons.event_outlined,
  Icons.event_busy_outlined,
  Icons.notifications_none,
  Icons.arrow_back,
];

/// Loads Material Icons before the HTML splash uncovers the first screen.
///
/// The family is declared with `uses-material-design`. The release build
/// tree-shakes the font; [keptMaterialIcons] keeps every glyph the UI draws.
Future<void> warmMaterialIcons() async {
  // A live read so dart2js cannot drop the const list.
  if (keptMaterialIcons.isEmpty) return;
  try {
    final data = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(data));
    await loader.load();
  } catch (_) {
    // The engine may already have registered the family from the manifest.
  }
  await confirmMaterialIconsLoaded();
}
