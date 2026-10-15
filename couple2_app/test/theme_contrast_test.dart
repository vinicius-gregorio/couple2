import 'dart:math' as math;

import 'package:couple2_app/app/routing/session_redirect.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary text meets contrast and disabled buttons are not the same fill', (
    tester,
  ) async {
    final scheme = lightColorScheme;
    expect(_contrast(scheme.primary, scheme.onPrimary), greaterThanOrEqualTo(4.5));
    expect(scheme.onPrimary, const Color(0xFFFFFFFF));
    expect(scheme.primary.computeLuminance(), lessThan(0.2));

    final enabled = lightTheme.filledButtonTheme.style!.backgroundColor!
        .resolve(const <WidgetState>{});
    final disabled = lightTheme.filledButtonTheme.style!.backgroundColor!
        .resolve(const <WidgetState>{WidgetState.disabled});
    final enabledLabel = lightTheme.filledButtonTheme.style!.foregroundColor!
        .resolve(const <WidgetState>{});
    final disabledLabel = lightTheme.filledButtonTheme.style!.foregroundColor!
        .resolve(const <WidgetState>{WidgetState.disabled});
    expect(disabled, const Color(0xFFE4DEE1));
    expect(disabledLabel, scheme.onSurface.withValues(alpha: 0.38));

    expect(enabled, scheme.primary);
    expect(enabledLabel, scheme.onPrimary);
    expect(disabled, isNot(enabled));
    expect(disabledLabel, isNot(enabledLabel));
    expect(disabled!.computeLuminance(), greaterThan(0.6));

    final textEnabled = lightTheme.textButtonTheme.style!.foregroundColor!
        .resolve(const <WidgetState>{});
    final textDisabled = lightTheme.textButtonTheme.style!.foregroundColor!
        .resolve(const <WidgetState>{WidgetState.disabled});
    expect(textEnabled, scheme.primary);
    expect(textDisabled, isNot(textEnabled));

    final filled = lightTheme.filledButtonTheme.style!.backgroundColor!
        .resolve(const <WidgetState>{});
    expect(filled, scheme.primary);
    expect(
      lightTheme.outlinedButtonTheme.style!.foregroundColor!.resolve(const {}),
      scheme.primary,
    );
  });

  test('session splash stays up until login and the couple session are known', () {
    expect(showSessionSplash(loggedIn: null, session: const AsyncData(null)), isTrue);
    expect(showSessionSplash(loggedIn: false, session: const AsyncData(null)), isFalse);
    expect(
      showSessionSplash(loggedIn: true, session: const AsyncLoading()),
      isTrue,
    );
    expect(
      showSessionSplash(loggedIn: true, session: const AsyncData(null)),
      isFalse,
    );
  });
}

double _contrast(Color a, Color b) {
  final lighter = math.max(a.computeLuminance(), b.computeLuminance());
  final darker = math.min(a.computeLuminance(), b.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}
