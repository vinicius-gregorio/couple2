import 'dart:js_interop';

@JS('document.fonts.load')
external JSPromise<JSAny?> _loadMaterialIcons(JSString spec);

@JS('document.fonts.check')
external bool _materialIconsReady(JSString spec);

/// Blocks the splash until the browser can paint Material Icons.
Future<void> confirmMaterialIconsLoaded() async {
  final spec = '24px MaterialIcons'.toJS;
  try {
    await _loadMaterialIcons(spec).toDart;
  } catch (_) {
    // FontLoader may already have registered the family.
  }
  if (!_materialIconsReady(spec)) {
    throw StateError('MaterialIcons');
  }
}
