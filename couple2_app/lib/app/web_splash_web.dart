import 'dart:js_interop';

@JS('document.getElementById')
external JSObject? _splashElement(JSString id);

extension type _SplashNode(JSObject _) implements JSObject {
  external void remove();
}

void removeWebSplash() {
  final node = _splashElement('flutter-splash'.toJS);
  if (node == null) return;
  _SplashNode(node).remove();
}
