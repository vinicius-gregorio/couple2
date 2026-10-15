import 'package:flutter/material.dart';
import 'theme.dart';

CardThemeData lightCardTheme() {
  return CardThemeData(
    color: AppColors.surfaceLight,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
  );
}

CardThemeData darkCardTheme() {
  return CardThemeData(
    color: AppColors.surfaceDark,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.largeRadius),
  );
}
