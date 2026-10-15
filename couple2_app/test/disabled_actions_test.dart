import 'package:couple2_app/app/routing/routes.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/auth/ui/widgets/apple_sign_in_button.dart';
import 'package:couple2_app/modules/daily_question/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_page.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_viewmodel.dart';
import 'package:couple2_app/modules/date_plans/routing/routes.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plans/date_plans_page.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/list_detail/list_detail_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enviar stays disabled while the answer is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_QuietSession.new),
          todayQuestionViewModelProvider.overrideWith(_ReadyQuestion.new),
        ],
        child: MaterialApp(theme: lightTheme, home: const TodayQuestionPage()),
      ),
    );
    await tester.pump();

    FilledButton button() {
      return tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar'),
      );
    }

    expect(button().onPressed, isNull);
    expect(
      _fill(tester, find.widgetWithText(FilledButton, 'Enviar')),
      lightColorScheme.surfaceContainerHighest,
    );

    await tester.enterText(find.byType(TextField), 'O café da manhã');
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(
      _fill(tester, find.widgetWithText(FilledButton, 'Enviar')),
      lightColorScheme.primary,
    );
  });

  testWidgets('gifts add stays disabled until the item has text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [listsViewModelProvider.overrideWith(_GiftLists.new)],
        child: MaterialApp(
          theme: lightTheme,
          home: const ListDetailPage(listId: 'gifts'),
        ),
      ),
    );
    await tester.pump();

    final addButton = find.widgetWithIcon(IconButton, Icons.add);
    IconButton add() => tester.widget<IconButton>(addButton);

    expect(add().onPressed, isNull);
    expect(_fill(tester, addButton), lightColorScheme.surfaceContainerHighest);

    await tester.enterText(find.byType(TextField).last, 'Flores');
    await tester.pump();
    expect(add().onPressed, isNotNull);
    expect(_fill(tester, addButton), lightColorScheme.primary);
    final icon = tester.widget<Icon>(find.byIcon(Icons.add));
    final iconTheme = IconTheme.of(tester.element(find.byIcon(Icons.add)));
    expect(icon.color ?? iconTheme.color, lightColorScheme.onPrimary);
  });

  testWidgets('apple sign-in shows a spinner while loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          body: AppleSignInButton(onPressed: () {}, isLoading: true),
        ),
      ),
    );

    expect(find.byKey(AppleSignInButton.loadingIndicatorKey), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(
      _fill(tester, find.byType(ElevatedButton)),
      lightColorScheme.inverseSurface,
    );
  });

  testWidgets('dates keeps a back arrow that goes home when nothing can pop', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: DatePlanRoutes.list,
      routes: [
        GoRoute(
          path: APPRoutes.home,
          builder: (_, __) => const Text('home-screen'),
        ),
        GoRoute(
          path: DatePlanRoutes.list,
          builder: (_, __) => const DatePlansPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    expect(find.byType(BackButtonIcon), findsOneWidget);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('home-screen'), findsOneWidget);
  });
}

Color? _fill(WidgetTester tester, Finder finder) {
  return tester
      .widget<Material>(
        find.descendant(of: finder, matching: find.byType(Material)).first,
      )
      .color;
}

class _QuietSession extends SessionNotifier {
  @override
  Future<Session?> build() async => null;
}

class _ReadyQuestion extends TodayQuestionViewModel {
  @override
  TodayQuestionState build() {
    return const TodayQuestionState(
      question: CoupleQuestion(
        id: 'q1',
        date: '2026-10-15',
        question: QuestionPrompt(
          text: 'O que te fez sorrir?',
          category: 'DAILY',
        ),
        partnerAnswered: false,
        answerable: true,
      ),
    );
  }

  @override
  Future<void> load() async {}
}

class _GiftLists extends ListsViewModel {
  @override
  ListsState build() {
    return ListsState(
      lists: [
        PartnerList(
          id: 'gifts',
          type: 'GIFT_IDEAS',
          name: 'Presentes',
          ownerId: 'user-a',
          items: const [],
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
  }
}
