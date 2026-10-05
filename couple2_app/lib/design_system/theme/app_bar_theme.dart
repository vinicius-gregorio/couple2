import 'package:flutter/material.dart';
import 'theme.dart';

AppBarTheme lightAppBarTheme() {
  return const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.softGray,
    elevation: 0,
    centerTitle: true,
  );
}

AppBarTheme darkAppBarTheme() {
  return AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    foregroundColor: Colors.grey.shade200,
    elevation: 0,
    centerTitle: true,
  );
}
