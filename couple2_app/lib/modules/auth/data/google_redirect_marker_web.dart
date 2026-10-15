import 'dart:js_interop';

const _pendingKey = 'couple2.googleRedirect';

@JS('sessionStorage')
external _WebStorage get _sessionStorage;

extension type _WebStorage(JSObject _) implements JSObject {
  external void setItem(JSString key, JSString value);
  external JSString? getItem(JSString key);
  external void removeItem(JSString key);
}

void markGoogleRedirectPending() {
  try {
    _sessionStorage.setItem(_pendingKey.toJS, '1'.toJS);
  } catch (_) {
    // Private mode can reject storage. The pageshow check still clears
    // a restored spinner.
  }
}

void clearGoogleRedirectPending() {
  try {
    _sessionStorage.removeItem(_pendingKey.toJS);
  } catch (_) {
    // Storage can be blocked. The in-memory sign-in state still resets.
  }
}

bool googleRedirectIsPending() {
  try {
    return _sessionStorage.getItem(_pendingKey.toJS)?.toDart == '1';
  } catch (_) {
    return false;
  }
}
