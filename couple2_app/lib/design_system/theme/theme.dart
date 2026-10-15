import 'package:flutter/material.dart';

import 'app_bar_theme.dart';
import 'app_font.dart';
import 'button_themes.dart';
import 'card_theme.dart';
import 'divider_theme.dart';
import 'input_decoration_theme.dart';
import 'text_theme.dart';

/// Single palette for light and dark themes.
///
/// Primary is a deep rose so white label text stays near 8:1. The old blush
/// (`#EDBAC7`) with white text was about 1.7:1 and read as a disabled control.
class AppColors {
  static const Color primary = Color(0xFF9D174D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFD9E4);
  static const Color onPrimaryContainer = Color(0xFF3E0018);

  static const Color secondary = Color(0xFF6D3A48);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFF6DCE3);
  static const Color onSecondaryContainer = Color(0xFF2C151B);

  static const Color tertiary = Color(0xFF7A5630);
  static const Color onTertiary = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  static const Color backgroundLight = Color(0xFFFDFBF8);
  static const Color backgroundDark = Color(0xFF1F1316);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D1E21);

  static const Color onSurfaceLight = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFF6EEF0);
  static const Color onSurfaceVariantLight = Color(0xFF4E4448);
  static const Color onSurfaceVariantDark = Color(0xFFD7C2C8);

  static const Color outlineLight = Color(0xFF80747A);
  static const Color outlineDark = Color(0xFF9E8C93);
  static const Color outlineVariantLight = Color(0xFFD5C4CA);
  static const Color outlineVariantDark = Color(0xFF5C4A50);

  /// Gray fill used for disabled buttons. Kept far from [primary].
  static const Color disabledContainerLight = Color(0xFFE4DEE1);
  static const Color disabledContainerDark = Color(0xFF3A3236);

  static const Color inverseSurfaceLight = Color(0xFF1C1B1F);
  static const Color onInverseSurfaceLight = Color(0xFFFFFFFF);
  static const Color inverseSurfaceDark = Color(0xFFF6EEF0);
  static const Color onInverseSurfaceDark = Color(0xFF1C1B1F);

  static const Color dividerLight = outlineVariantLight;
  static const Color dividerDark = outlineVariantDark;

  /// Kept so older call sites that read the muted body color still compile.
  static const Color softGray = onSurfaceVariantLight;
  static const Color headlineLight = onSurfaceLight;
  static const Color headlineDark = onSurfaceDark;
}

/// App border radius constants
class AppRadius {
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double full = 9999.0;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius fullRadius = BorderRadius.all(
    Radius.circular(full),
  );
}

/// App box shadows
class AppShadows {
  static const BoxShadow soft = BoxShadow(
    offset: Offset(0, 10),
    blurRadius: 25,
    spreadRadius: -5,
    color: Color.fromRGBO(157, 23, 77, 0.12),
  );

  static const BoxShadow float = BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 20,
    color: Color.fromRGBO(28, 27, 31, 0.08),
  );
}

const ColorScheme lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.primaryContainer,
  onPrimaryContainer: AppColors.onPrimaryContainer,
  secondary: AppColors.secondary,
  onSecondary: AppColors.onSecondary,
  secondaryContainer: AppColors.secondaryContainer,
  onSecondaryContainer: AppColors.onSecondaryContainer,
  tertiary: AppColors.tertiary,
  onTertiary: AppColors.onTertiary,
  error: AppColors.error,
  onError: AppColors.onError,
  errorContainer: AppColors.errorContainer,
  onErrorContainer: AppColors.onErrorContainer,
  surface: AppColors.surfaceLight,
  onSurface: AppColors.onSurfaceLight,
  onSurfaceVariant: AppColors.onSurfaceVariantLight,
  outline: AppColors.outlineLight,
  outlineVariant: AppColors.outlineVariantLight,
  surfaceContainerHighest: AppColors.disabledContainerLight,
  inverseSurface: AppColors.inverseSurfaceLight,
  onInverseSurface: AppColors.onInverseSurfaceLight,
  surfaceTint: Colors.transparent,
);

const ColorScheme darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.onPrimaryContainer,
  onPrimaryContainer: AppColors.primaryContainer,
  secondary: AppColors.secondary,
  onSecondary: AppColors.onSecondary,
  secondaryContainer: Color(0xFF4A2732),
  onSecondaryContainer: AppColors.secondaryContainer,
  tertiary: AppColors.tertiary,
  onTertiary: AppColors.onTertiary,
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: AppColors.surfaceDark,
  onSurface: AppColors.onSurfaceDark,
  onSurfaceVariant: AppColors.onSurfaceVariantDark,
  outline: AppColors.outlineDark,
  outlineVariant: AppColors.outlineVariantDark,
  surfaceContainerHighest: AppColors.disabledContainerDark,
  inverseSurface: AppColors.inverseSurfaceDark,
  onInverseSurface: AppColors.onInverseSurfaceDark,
  surfaceTint: Colors.transparent,
);

/// Light theme configuration
final ThemeData lightTheme = _theme(lightColorScheme, Brightness.light);

/// Dark theme configuration
final ThemeData darkTheme = _theme(darkColorScheme, Brightness.dark);

ThemeData _theme(ColorScheme scheme, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final text = isLight ? lightTextTheme() : darkTextTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallbacks,
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: isLight
        ? AppColors.backgroundLight
        : AppColors.backgroundDark,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: isLight ? lightAppBarTheme() : darkAppBarTheme(),
    cardTheme: isLight ? lightCardTheme() : darkCardTheme(),
    elevatedButtonTheme: elevatedButtonTheme(scheme),
    filledButtonTheme: filledButtonTheme(scheme),
    outlinedButtonTheme: outlinedButtonTheme(scheme),
    textButtonTheme: textButtonTheme(scheme),
    iconButtonTheme: iconButtonTheme(),
    floatingActionButtonTheme: floatingActionButtonTheme(scheme),
    inputDecorationTheme: inputDecorationTheme(scheme),
    dividerTheme: isLight ? lightDividerTheme() : darkDividerTheme(),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primaryContainer,
      selectionHandleColor: scheme.primary,
    ),
  );
}
