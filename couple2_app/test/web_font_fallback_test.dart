import 'dart:io';

import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme text uses Plus Jakarta and not a remote fallback family', () {
    for (final theme in [lightTheme, darkTheme]) {
      final styles = <TextStyle?>[
        theme.textTheme.displayLarge,
        theme.textTheme.displayMedium,
        theme.textTheme.displaySmall,
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.titleSmall,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ];
      for (final style in styles) {
        expect(style, isNotNull);
        expect(style!.fontFamily, kAppFontFamily);
        expect(style.fontFamilyFallback, kAppFontFallbacks);
        expect(style.fontFamily, isNot('Roboto'));
      }
    }
    expect(appButtonTextStyle().fontFamily, kAppFontFamily);
    expect(appTextButtonTextStyle().fontFamily, kAppFontFamily);
  });

  test('bootstrap leaves font fallback to the engine and fails the splash open', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    final html = File('web/index.html').readAsStringSync();

    expect(bootstrap, isNot(contains('fontFallbackBaseUrl')));
    expect(bootstrap, isNot(contains('fallback_fonts')));
    expect(bootstrap, contains('initializeEngine'));
    expect(bootstrap, contains('180000'));
    expect(bootstrap, contains("addEventListener('error', showSplashFailure)"));

    expect(html, contains('Recarregar'));
    expect(html, contains('Não foi possível carregar'));
    expect(html, contains('<svg class="mark"'));
    expect(html, isNot(contains('setTimeout')));
    expect(Directory('web/fallback_fonts').existsSync(), isFalse);
  });
}
