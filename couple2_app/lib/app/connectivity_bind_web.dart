import 'dart:js_interop';

@JS('window')
external _BrowserWindow get _window;

extension type _BrowserWindow(JSObject _) implements JSObject {
  external _BrowserNavigator get navigator;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _BrowserNavigator(JSObject _) implements JSObject {
  external bool get onLine;
}

/// Browser `online` / `offline` events, plus the current `navigator.onLine`.
void Function() listenBrowserOnline(void Function(bool online) onChange) {
  void online(JSAny? _) => onChange(true);
  void offline(JSAny? _) => onChange(false);
  final onOnline = online.toJS;
  final onOffline = offline.toJS;
  _window.addEventListener('online', onOnline);
  _window.addEventListener('offline', onOffline);
  // After the provider finishes build. Setting state during build is illegal.
  Future<void>.microtask(() => onChange(_window.navigator.onLine));
  return () {
    _window.removeEventListener('online', onOnline);
    _window.removeEventListener('offline', onOffline);
  };
}
