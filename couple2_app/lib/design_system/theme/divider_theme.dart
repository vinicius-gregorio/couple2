import 'package:flutter/material.dart';
import 'theme.dart';

DividerThemeData lightDividerTheme() {
  return const DividerThemeData(color: AppColors.dividerLight, thickness: 1);
}

DividerThemeData darkDividerTheme() {
  return const DividerThemeData(color: AppColors.dividerDark, thickness: 1);
}
