import 'package:flutter/material.dart';

/// Marks the subtree of [showAppSheet] so action errors stay in the sheet.
class AppSheetScope extends InheritedWidget {
  const AppSheetScope({super.key, required super.child});

  static bool isInSheet(BuildContext context) {
    return context.findAncestorWidgetOfExactType<AppSheetScope>() != null;
  }

  @override
  bool updateShouldNotify(AppSheetScope oldWidget) => false;
}
