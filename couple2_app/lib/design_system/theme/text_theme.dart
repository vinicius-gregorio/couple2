import 'package:flutter/material.dart';

import 'app_font.dart';
import 'theme.dart';

TextTheme lightTextTheme() => _textTheme(
  headline: AppColors.headlineLight,
  body: AppColors.onSurfaceLight,
  muted: AppColors.onSurfaceVariantLight,
);

TextTheme darkTextTheme() => _textTheme(
  headline: AppColors.headlineDark,
  body: AppColors.onSurfaceDark,
  muted: AppColors.onSurfaceVariantDark,
);

TextTheme _textTheme({
  required Color headline,
  required Color body,
  required Color muted,
}) {
  TextStyle style({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
  }) {
    return appTextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  return TextTheme(
    displayLarge: style(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: headline,
      letterSpacing: -0.5,
    ),
    headlineLarge: style(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: headline,
      letterSpacing: -0.5,
    ),
    headlineMedium: style(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: headline,
    ),
    headlineSmall: style(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: headline,
    ),
    titleLarge: style(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: headline,
    ),
    titleMedium: style(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: body,
    ),
    titleSmall: style(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: body,
    ),
    bodyLarge: style(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: body,
    ),
    bodyMedium: style(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: body,
    ),
    bodySmall: style(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: muted,
    ),
    labelLarge: style(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: muted,
    ),
    labelSmall: style(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: muted,
      letterSpacing: 0.5,
    ),
  );
}
