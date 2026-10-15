import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Label style without a color so [ColorScheme.onPrimary] wins.
TextStyle appButtonTextStyle() {
  return GoogleFonts.plusJakartaSans(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: null,
  );
}

TextStyle appTextButtonTextStyle() {
  return GoogleFonts.plusJakartaSans(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: null,
  );
}

Color disabledForeground(ColorScheme scheme) {
  return scheme.onSurface.withValues(alpha: 0.38);
}

ElevatedButtonThemeData elevatedButtonTheme(ColorScheme scheme) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      disabledForegroundColor: disabledForeground(scheme),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(64, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      textStyle: appButtonTextStyle(),
    ),
  );
}

FilledButtonThemeData filledButtonTheme(ColorScheme scheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      disabledForegroundColor: disabledForeground(scheme),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(64, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      textStyle: appButtonTextStyle(),
    ),
  );
}

OutlinedButtonThemeData outlinedButtonTheme(ColorScheme scheme) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: scheme.primary,
      disabledForegroundColor: disabledForeground(scheme),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      minimumSize: const Size(64, 48),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
      textStyle: appButtonTextStyle(),
      side: BorderSide(color: scheme.primary, width: 1.5),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.12),
            width: 1.5,
          );
        }
        return BorderSide(color: scheme.primary, width: 1.5);
      }),
    ),
  );
}

TextButtonThemeData textButtonTheme(ColorScheme scheme) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: scheme.primary,
      disabledForegroundColor: disabledForeground(scheme),
      textStyle: appTextButtonTextStyle(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

IconButtonThemeData iconButtonTheme(ColorScheme scheme) {
  return IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: scheme.onSurface,
      disabledForegroundColor: disabledForeground(scheme),
    ),
  );
}

FloatingActionButtonThemeData floatingActionButtonTheme(ColorScheme scheme) {
  return FloatingActionButtonThemeData(
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
  );
}
