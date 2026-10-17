import 'package:flutter/material.dart';

/// Loaded-card heights. A load error is the shared error card, not this slot.
const homeMoodCardHeight = 520.0;
const homeDaysCardHeight = 208.0;
const homeNextDateCardHeight = 200.0;
const homeQuestionCardHeight = 160.0;
const homeFeedCardHeight = 300.0;

/// Home reads share one retry.
class HomeFailureScope extends InheritedWidget {
  const HomeFailureScope({
    super.key,
    required this.retryAll,
    required super.child,
  });

  final VoidCallback retryAll;

  /// Reloads every Home read. False when this card is not on Home.
  static bool retry(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<HomeFailureScope>();
    if (scope == null) return false;
    scope.retryAll();
    return true;
  }

  @override
  bool updateShouldNotify(HomeFailureScope oldWidget) {
    return retryAll != oldWidget.retryAll;
  }
}
