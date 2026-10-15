import 'dart:async';

import 'package:couple2_app/app/splash_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splash stays up until the logo and font are ready', () async {
    var removed = false;
    final ready = Completer<void>();
    final pending = dismissSplashWhenReady(
      assetsReady: ready.future,
      removeSplash: () => removed = true,
      timeout: const Duration(seconds: 2),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(removed, isFalse);

    ready.complete();
    await pending;
    expect(removed, isTrue);
  });

  test('splash is removed when assets never finish', () async {
    var removed = false;

    await dismissSplashWhenReady(
      assetsReady: Completer<void>().future,
      removeSplash: () => removed = true,
      timeout: const Duration(milliseconds: 20),
    );

    expect(removed, isTrue);
  });
}
