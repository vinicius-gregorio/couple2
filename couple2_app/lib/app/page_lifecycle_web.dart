import 'dart:js_interop';

@JS('window')
external JSObject get _pageWindow;

extension type _PageWindow(JSObject _) implements JSObject {
  external void addEventListener(JSString type, JSFunction listener);
}

extension type _PageShowEvent(JSObject _) implements JSObject {
  external bool get persisted;
}

/// Fires [onPersisted] when the browser restores this document from the
/// back-forward cache (`pageshow` with `persisted == true`).
void listenForRestoredPage(void Function() onPersisted) {
  _PageWindow(_pageWindow).addEventListener(
    'pageshow'.toJS,
    ((JSObject event) {
      if (_PageShowEvent(event).persisted) onPersisted();
    }).toJS,
  );
}
