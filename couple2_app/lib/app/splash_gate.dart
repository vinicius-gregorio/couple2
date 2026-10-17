/// Removes the HTML splash after [assetsReady], and still removes it if that
/// work stalls. The login screen stays covered until the logo and font can
/// paint, and the splash cannot sit on top of the app forever.
Future<void> dismissSplashWhenReady({
  required Future<void> assetsReady,
  required void Function() removeSplash,
  Duration timeout = const Duration(seconds: 3),
  Future<void> Function()? afterReady,
}) async {
  try {
    await assetsReady.timeout(timeout);
    if (afterReady != null) await afterReady();
  } catch (_) {
    // A failed or slow font must not leave the splash up.
  }
  removeSplash();
}
