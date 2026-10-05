import 'package:flutter/material.dart';

import 'app_bar_theme.dart';
import 'card_theme.dart';
import 'divider_theme.dart';
import 'elevated_button_theme.dart';
import 'input_decoration_theme.dart';
import 'text_button_theme.dart';
import 'text_theme.dart';

/// App color palette extracted from design system
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFEDBAC7);

  // Background colors
  static const Color backgroundLight = Color(0xFFFDFBF8);
  static const Color backgroundDark = Color(0xFF1F1316);

  // Text colors
  static const Color softGray = Color(0xFF4A4A4A);
  static const Color headlineLight = Color(0xFF171213);
  static const Color headlineDark = Colors.white;

  // Surface colors (cards, inputs)
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF2D1E21);

  // Divider colors
  static const Color dividerLight = Color(0xFFE5E5E5);
  static const Color dividerDark = Color(0xFF374151);
}

/// App border radius constants
class AppRadius {
  static const double small = 8.0; // 0.5rem
  static const double medium = 16.0; // 1rem
  static const double large = 24.0; // 1.5rem
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
    color: Color.fromRGBO(237, 186, 199, 0.1),
  );

  static const BoxShadow float = BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 20,
    color: Color.fromRGBO(74, 74, 74, 0.06),
  );
}

/// Light theme configuration
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.softGray,
    surfaceContainerHighest: AppColors.backgroundLight,
  ),
  scaffoldBackgroundColor: AppColors.backgroundLight,
  appBarTheme: lightAppBarTheme(),
  cardTheme: lightCardTheme(),
  elevatedButtonTheme: elevatedButtonTheme(),
  textButtonTheme: textButtonTheme(),
  inputDecorationTheme: lightInputDecorationTheme(),
  dividerTheme: lightDividerTheme(),
  textTheme: lightTextTheme(),
);

/// Dark theme configuration
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surfaceDark,
    onSurface: Colors.grey.shade200,
    surfaceContainerHighest: AppColors.backgroundDark,
  ),
  scaffoldBackgroundColor: AppColors.backgroundDark,
  appBarTheme: darkAppBarTheme(),
  cardTheme: darkCardTheme(),
  elevatedButtonTheme: elevatedButtonTheme(),
  textButtonTheme: textButtonTheme(),
  inputDecorationTheme: darkInputDecorationTheme(),
  dividerTheme: darkDividerTheme(),
  textTheme: darkTextTheme(),
);
