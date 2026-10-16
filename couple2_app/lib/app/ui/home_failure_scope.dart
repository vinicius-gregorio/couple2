import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error.dart';

/// Shared heights for a Home card's skeleton, load-error, and loaded body.
/// Tall enough for the loaded body. Error copy in a tall slot stays at the
/// top so a phone fold still shows the message and the retry.
const homeMoodCardHeight = 520.0;
const homeDaysCardHeight = 208.0;
const homeNextDateCardHeight = 200.0;
const homeQuestionCardHeight = 160.0;
const homeFeedCardHeight = 300.0;

const homeMoodLoadError = 'Não foi possível carregar o humor.';
const homeDaysLoadError = 'Não foi possível carregar os dias juntos.';
const homeDatesLoadError = 'Não foi possível carregar os encontros.';
const homeQuestionLoadError = 'Não foi possível carregar a pergunta.';
const homeFeedLoadError = 'Não foi possível carregar o que rolou.';

/// Offline failures keep the short card line. The notice owns the long sentence.
/// Any other failure uses the shared mapping, including a slow connection.
String homeCardMessage(Object error, String offlineLine) {
  if (isOfflineFailure(error)) return offlineLine;
  return userFacingError(error);
}

/// Home reads share one retry. The offline sentence lives on the notice.
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
