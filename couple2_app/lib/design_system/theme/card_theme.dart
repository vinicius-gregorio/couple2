import 'package:flutter/material.dart';
import 'theme.dart';

CardThemeData lightCardTheme() {
  return CardThemeData(
    color: AppColors.surfaceLight,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
  );
}

CardThemeData darkCardTheme() {
  return CardThemeData(
    color: AppColors.surfaceDark,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
  );
}
