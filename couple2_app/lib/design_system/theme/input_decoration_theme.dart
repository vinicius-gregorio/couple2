import 'package:flutter/material.dart';

import 'theme.dart';

InputDecorationTheme inputDecorationTheme(ColorScheme scheme) {
  final radius = AppRadius.largeRadius;
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surface,
    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    floatingLabelStyle: TextStyle(color: scheme.primary),
    prefixIconColor: scheme.onSurfaceVariant,
    suffixIconColor: scheme.onSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

InputDecorationTheme lightInputDecorationTheme() {
  return inputDecorationTheme(lightColorScheme);
}

InputDecorationTheme darkInputDecorationTheme() {
  return inputDecorationTheme(darkColorScheme);
}
