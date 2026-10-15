import 'package:couple2_app/app/providers.dart';
import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_page.dart';
import 'package:couple2_app/modules/auth/ui/pages/auth/auth_viewmodel.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/daily_question/domain/domain.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/date_plans/domain/domain.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_page.dart';
import 'package:couple2_app/modules/daily_question/ui/pages/today/today_question_viewmodel.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_repository.dart';
import 'package:couple2_app/modules/date_plans/ui/pages/date_plans/date_plans_page.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/list_detail/list_detail_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/pairing/ui/pages/enter_code/enter_code_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_viewmodel.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/modules/pairing/data/pairing_providers.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:couple2_app/modules/pairing/ui/pages/pairing_code/pairing_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local screenshot harness. Not part of the product routes.
/// Open `/?screen=login|login-loading|pairing|enter-code|home|lists-loading|lists-error|lists-empty|lists-ready|gifts|question|dates|buttons`.
final String galleryScreen = Uri.base.queryParameters['screen'] ?? 'login';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(_GalleryAuth.new),
        sessionProvider.overrideWith(_GallerySession.new),
        pairingStatusProvider.overrideWith(_GalleryPairing.new),
        pairingPollIntervalProvider.overrideWithValue(null),
        logoutActionProvider.overrideWithValue(() async {}),
        coupleProvider.overrideWith((ref) async => _couple),
        unreadCountProvider.overrideWith((ref) async => 2),
        feedPreviewProvider.overrideWith((ref) async => _feed),
        todayQuestionProvider.overrideWith((ref) async => _question),
        currentMoodProvider.overrideWith((ref) async => _mood),
        nextDateProvider.overrideWith((ref) async => _plan),
        datePlansRepositoryProvider.overrideWithValue(_GalleryDates()),
        todayQuestionViewModelProvider.overrideWith(_GalleryQuestion.new),
        listsViewModelProvider.overrideWith(_GalleryLists.new),
      ],
      child: const GalleryApp(),
    ),
  );
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: switch (galleryScreen) {
        'pairing' => const PairingCodePage(),
        'enter-code' => const EnterCodePage(),
        'home' => const HomePage(),
        'lists-loading' ||
        'lists-error' ||
        'lists-empty' ||
        'lists-ready' => const ListsPage(),
        'gifts' => const ListDetailPage(listId: 'gifts'),
        'question' => const TodayQuestionPage(),
        'dates' => const DatePlansPage(),
        'buttons' => const _ButtonsPreview(),
        _ => const AuthPage(),
      },
    );
  }
}

class _GalleryAuth extends AuthViewModel {
  @override
  AuthState build() {
    if (galleryScreen == 'login-loading') {
      return const AuthState(isLoading: true);
    }
    return const AuthState();
  }
}

class _GallerySession extends SessionNotifier {
  @override
  Future<Session?> build() async => _session;
}

class _GalleryPairing extends PairingStatusNotifier {
  @override
  Future<PairingSnapshot> build() async {
    return PairingSnapshot(
      phase: PairingPhase.unpaired,
      pairingCode: 'AB12CD',
      pairingCodeExpiresAt: DateTime.utc(2026, 10, 16, 18),
    );
  }
}

class _GalleryLists extends ListsViewModel {
  @override
  ListsState build() {
    switch (galleryScreen) {
      case 'lists-error':
        return const ListsState(errorMessage: 'Sem conexão com o servidor');
      case 'lists-empty':
        return const ListsState();
      case 'gifts':
      case 'lists-ready':
        return ListsState(lists: [_giftList]);
      default:
        return const ListsState(isLoading: true);
    }
  }
}

class _ButtonsPreview extends StatelessWidget {
  const _ButtonsPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buttons')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Enabled'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          const SizedBox(height: 8),
          TextButton(onPressed: () {}, child: const Text('Text')),
          const SizedBox(height: 24),
          const Text('Disabled'),
          const SizedBox(height: 8),
          const ElevatedButton(onPressed: null, child: Text('Elevated')),
          const SizedBox(height: 8),
          const FilledButton(onPressed: null, child: Text('Filled')),
          const SizedBox(height: 8),
          const OutlinedButton(onPressed: null, child: Text('Outlined')),
          const SizedBox(height: 8),
          const TextButton(onPressed: null, child: Text('Text')),
          const SizedBox(height: 24),
          const Text('Loading'),
          const SizedBox(height: 8),
          LoadingButton(
            loading: true,
            onPressed: () {},
            child: const Text('Enviando...'),
          ),
        ],
      ),
    );
  }
}

const _session = Session(
  id: 'user-a',
  email: 'ana@example.com',
  name: 'Ana',
  isPaired: true,
  coupleId: 'couple-1',
  partnerId: 'user-b',
  partnerName: 'Bruno',
  pairingCode: 'AB12CD',
);

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2024, 2, 14),
  anniversaryDate: '2024-02-14',
  timezone: 'America/Sao_Paulo',
  daysTogether: 600,
  partner: const CouplePartner(id: 'user-b', name: 'Bruno'),
  upcoming: const [],
);

final _mood = MoodCurrent(
  me: MoodSnapshot(
    mood: MoodLevel.good,
    createdAt: DateTime.utc(2026, 10, 15, 12),
    stale: false,
  ),
  partner: MoodSnapshot(
    mood: MoodLevel.great,
    createdAt: DateTime.utc(2026, 10, 15, 11),
    stale: false,
  ),
);

final _plan = DatePlan(
  id: 'plan-1',
  coupleId: 'couple-1',
  proposerId: 'user-a',
  title: 'Japonês',
  scheduledAt: DateTime(2026, 10, 18, 20),
  status: DatePlanStatus.accepted,
  createdById: 'user-a',
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

final _question = CoupleQuestion(
  id: 'q1',
  date: '2026-10-15',
  question: const QuestionPrompt(
    text: 'O que te fez sorrir hoje?',
    category: 'DAILY',
  ),
  partnerAnswered: false,
  answerable: true,
);

final _giftList = PartnerList(
  id: 'gifts',
  type: 'GIFT_IDEAS',
  name: 'Presentes',
  ownerId: 'user-a',
  items: const [],
  createdAt: DateTime.utc(2026, 1, 1),
);

class _GalleryQuestion extends TodayQuestionViewModel {
  @override
  TodayQuestionState build() => TodayQuestionState(question: _question);

  @override
  Future<void> load() async {}
}

class _GalleryDates implements IDatePlansRepository {
  @override
  Future<DatePlanPage> list({required String scope, String? cursor}) async {
    return DatePlanPage(items: scope == 'upcoming' ? [_plan] : const []);
  }

  @override
  Future<DatePlan> get(String id) async => _plan;

  @override
  Future<DatePlan> create({
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
  }) => Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> update(
    String id, {
    String? title,
    DateTime? scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearSource = false,
  }) => Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> accept(String id) =>
      Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> decline(String id, {String? note}) =>
      Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> counter(
    String id, {
    required DateTime scheduledAt,
    String? note,
  }) => Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> cancel(String id, {String? note}) =>
      Future<DatePlan>.error(UnimplementedError());

  @override
  Future<DatePlan> done(String id) =>
      Future<DatePlan>.error(UnimplementedError());
}

final _feed = [
  ActivityEvent(
    id: 'e1',
    coupleId: 'couple-1',
    actorId: 'user-b',
    type: 'LIST_ITEM_ADDED',
    entityType: 'LIST_ITEM',
    entityId: 'item-1',
    payload: const {'actorName': 'Bruno', 'content': 'Flores'},
    createdAt: DateTime.utc(2026, 10, 15, 9),
  ),
];
