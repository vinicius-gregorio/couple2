import 'package:flutter/material.dart';

import 'app_font.dart';
import 'theme.dart';

/// Label style without a color so [ColorScheme.onPrimary] wins.
TextStyle appButtonTextStyle() {
  return appTextStyle(fontWeight: FontWeight.w700, fontSize: 16);
}

TextStyle appTextButtonTextStyle() {
  return appTextStyle(fontWeight: FontWeight.w600, fontSize: 14);
}

/// Disabled label is 38% of [ColorScheme.onSurface]. The fill is [disabledFill].
Color disabledForeground(ColorScheme scheme) {
  return scheme.onSurface.withValues(alpha: 0.38);
}

/// Gray fill for disabled primary controls. Never a blush or tonal pink.
const Color disabledFill = Color(0xFFE4DEE1);

FilledButtonThemeData filledButtonTheme(ColorScheme scheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      disabledBackgroundColor: disabledFill,
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
    style:
        OutlinedButton.styleFrom(
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
              return const BorderSide(color: disabledFill, width: 1.5);
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

/// Standard icon buttons are the tertiary variant: a wine glyph, no fill.
/// Filled icon buttons pass their own onPrimary style so this does not paint
/// a wine icon on the wine circle.
IconButtonThemeData iconButtonTheme(ColorScheme scheme) {
  return IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: scheme.primary,
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

/// Selected chips use the primary fill and white label. Unselected chips stay
/// transparent with a primary border so they never fall back to a blush fill.
ChipThemeData appChipTheme(ColorScheme scheme) {
  return ChipThemeData(
    backgroundColor: Colors.transparent,
    disabledColor: disabledFill,
    selectedColor: scheme.primary,
    checkmarkColor: scheme.onPrimary,
    side: BorderSide(color: scheme.primary),
    labelStyle: TextStyle(
      color: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledForeground(scheme);
        }
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.primary;
      }),
      fontWeight: FontWeight.w600,
    ),
    secondaryLabelStyle: TextStyle(
      color: scheme.onPrimary,
      fontWeight: FontWeight.w600,
    ),
    color: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return disabledFill;
      if (states.contains(WidgetState.selected)) return scheme.primary;
      return Colors.transparent;
    }),
  );
}
