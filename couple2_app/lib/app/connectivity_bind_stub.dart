/// VM and tests have no browser online/offline events.
void Function() listenBrowserOnline(void Function(bool online) onChange) {
  return () {};
}
