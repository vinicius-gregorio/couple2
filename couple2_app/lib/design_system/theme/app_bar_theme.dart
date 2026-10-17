import 'package:flutter/material.dart';

import 'theme.dart';

AppBarTheme lightAppBarTheme() {
  return const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.onSurfaceLight,
    iconTheme: IconThemeData(color: AppColors.primary),
    actionsIconTheme: IconThemeData(color: AppColors.primary),
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  );
}

AppBarTheme darkAppBarTheme() {
  return const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    foregroundColor: AppColors.onSurfaceDark,
    iconTheme: IconThemeData(color: AppColors.primary),
    actionsIconTheme: IconThemeData(color: AppColors.primary),
    elevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  );
}
