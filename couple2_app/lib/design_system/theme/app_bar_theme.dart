import 'package:flutter/material.dart';

import 'theme.dart';

AppBarTheme lightAppBarTheme() {
  return const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.onSurfaceLight,
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  );
}

AppBarTheme darkAppBarTheme() {
  return const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    foregroundColor: AppColors.onSurfaceDark,
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  );
}
