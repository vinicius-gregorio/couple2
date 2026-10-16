import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Opens the browser share sheet when `navigator.share` exists.
Future<bool> shareWithSheet(String text) async {
  final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
  if (navigator == null) return false;
  final share = navigator.getProperty<JSAny?>('share'.toJS);
  if (share == null || share.typeofEquals('undefined')) return false;
  try {
    final result = (share as JSFunction).callAsFunction(
      navigator,
      {'text': text}.jsify(),
    );
    if (result != null && result.isA<JSPromise>()) {
      await (result as JSPromise<JSAny?>).toDart;
    }
    return true;
  } catch (_) {
    return false;
  }
}
