import 'package:go_router/go_router.dart';

import '../ui/pages/history/question_history_page.dart';
import '../ui/pages/today/today_question_page.dart';
import 'routes.dart';

final dailyQuestionRoutes = [
  GoRoute(
    path: DailyQuestionRoutes.today,
    builder: (_, __) => const TodayQuestionPage(),
    routes: [
      GoRoute(path: 'history', builder: (_, __) => const QuestionHistoryPage()),
    ],
  ),
];
