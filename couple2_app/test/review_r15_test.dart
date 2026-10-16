import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/home_failure_scope.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/core/core.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/data/couple_repository.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/couple/ui/pages/important_dates/important_dates_page.dart';
import 'package:couple2_app/modules/couple/ui/widgets/days_together_card.dart';
import 'package:couple2_app/modules/couple/ui/widgets/profile_sheet.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/feed/domain/domain.dart';
import 'package:couple2_app/modules/lists/data/lists_providers.dart';
import 'package:couple2_app/modules/lists/data/lists_repository.dart';
import 'package:couple2_app/modules/lists/domain/domain.dart';
import 'package:couple2_app/modules/lists/ui/pages/list_detail/list_detail_page.dart';
import 'package:couple2_app/modules/lists/ui/pages/lists/lists_page.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_home_card.dart';
import 'package:couple2_app/modules/mood/ui/widgets/mood_picker_sheet.dart';
import 'package:couple2_app/modules/mood/ui/widgets/nudge_composer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ada = Session(
  id: 'ada',
  email: 'ada@example.com',
  name: 'Ada',
  isPaired: true,
  coupleId: 'couple-1',
  partnerName: 'Bruno',
);

class _Session extends SessionNotifier {
  _Session(this.current);

  final Session? current;

  @override
  Future<Session?> build() async => current;

  @override
  Future<void> refresh() async {}
}

class _OfflineSession extends SessionNotifier {
  @override
  Future<Session?> build() async {
    throw const CPLHttpNoInternetConnectionException();
  }

  @override
  Future<void> refresh() async {}
}

class _DatesRepo implements ICoupleRepository {
  _DatesRepo(this.dates);

  final List<CoupleDate> dates;

  @override
  Future<List<CoupleDate>> getDates() async => dates;

  @override
  Future<Couple> getCouple() => Future<Couple>.error(StateError('no'));

  @override
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone}) =>
      Future<Couple>.error(StateError('no'));

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {}

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) async => _date('new', title);

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) async => _date(id, title ?? '');

  @override
  Future<void> deleteDate(String id) async {}
}

class _ListsRepo implements IListsRepository {
  _ListsRepo(this.lists);

  List<PartnerList> lists;
  var failToggle = false;

  @override
  Future<List<PartnerList>> getLists() async => lists;

  @override
  Future<PartnerList> createList(
    String type,
    String name, {
    String? visibility,
  }) async => lists.first;

  @override
  Future<ListItem> addItem(
    String listId,
    String content,
    Map<String, dynamic>? metadata,
  ) async => lists.first.items.first;

  @override
  Future<ListItem> toggleItem(String itemId) async {
    if (failToggle) throw const CPLHttpNoInternetConnectionException();
    final item = lists.first.items.firstWhere((row) => row.id == itemId);
    return item.copyWith(isCompleted: !item.isCompleted);
  }

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteList(String listId) async {}
}

CoupleDate _date(String id, String title) {
  return CoupleDate(
    id: id,
    coupleId: 'couple-1',
    type: 'CUSTOM',
    title: title,
    date: '2026-12-01',
    recurrence: 'YEARLY',
    createdById: 'ada',
  );
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2026, 10, 10),
  anniversaryDate: '2026-10-10',
  timezone: 'America/Sao_Paulo',
  daysTogether: 7,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [],
);

ListItem _item(String id, String content) {
  return ListItem(
    id: id,
    listId: 'list-1',
    content: content,
    isCompleted: false,
    addedById: 'ada',
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

PartnerList _list() {
  return PartnerList(
    id: 'list-1',
    type: 'SHOPPING_CART',
    name: 'Mercado',
    ownerId: 'ada',
    items: [_item('i1', 'Leite'), _item('i2', 'Café'), _item('i3', 'Pão')],
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sheet fields take focus and text with semantics on', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> typeSheet(Finder field, String value) async {
        expect(field, findsOneWidget);
        await tester.ensureVisible(field);
        await tester.pump();
        final center = tester.getCenter(field);
        final hit = _hitSemantics(tester, center);
        expect(hit, isNotNull, reason: 'no semantics node at $center');
        final data = hit!.getSemanticsData();
        expect(
          data.flagsCollection.isTextField ||
              data.hasAction(SemanticsAction.setText),
          isTrue,
          reason:
              'hit "${data.label}" text=${data.flagsCollection.isTextField} '
              'button=${data.flagsCollection.isButton} rect=${data.rect}',
        );
        await tester.tap(field);
        await tester.pump();
        final editable = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        await tester.enterText(field, value);
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, value);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_ada)),
            listsRepositoryProvider.overrideWithValue(_ListsRepo([_list()])),
          ],
          child: MaterialApp(theme: lightTheme, home: ListsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nova lista'));
      await tester.pumpAndSettle();
      await typeSheet(find.widgetWithText(TextField, 'Nome'), 'Mercado novo');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_ada)),
            coupleRepositoryProvider.overrideWithValue(_DatesRepo(const [])),
            coupleProvider.overrideWith((ref) async => _couple),
          ],
          child: MaterialApp(
            theme: lightTheme,
            home: ImportantDatesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Adicionar data'));
      await tester.pumpAndSettle();
      await typeSheet(find.widgetWithText(TextField, 'Título'), 'Lua de mel');

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_ada)),
            coupleRepositoryProvider.overrideWithValue(
              _DatesRepo([_date('d1', 'Natal')]),
            ),
            coupleProvider.overrideWith((ref) async => _couple),
          ],
          child: MaterialApp(
            theme: lightTheme,
            home: ImportantDatesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await typeSheet(find.widgetWithText(TextField, 'Título'), 'Natal cedo');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(() => _Session(_ada)),
          ],
          child: MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingButton(
                  onPressed: () {
                    showAppSheet<void>(
                      context: context,
                      builder: (_) => ProfileSheet(session: _ada),
                    );
                  },
                  child: const Text('Abrir perfil'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir perfil'));
      await tester.pumpAndSettle();
      await typeSheet(find.byKey(const Key('profile-name-field')), 'Ada Nova');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingButton(
                  onPressed: () {
                    showMoodPickerSheet(context);
                  },
                  child: const Text('Abrir humor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir humor'));
      await tester.pumpAndSettle();
      await typeSheet(
        find.widgetWithText(TextField, 'Uma nota, se quiser'),
        'dia bom',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => LoadingButton(
                  onPressed: () {
                    showNudgeComposerSheet(context, onSend: (_) async {});
                  },
                  child: const Text('Abrir carinho'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir carinho'));
      await tester.pumpAndSettle();
      await typeSheet(
        find.widgetWithText(TextField, 'Uma frase, se quiser'),
        'saudade',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('one home notice reloads every card and then leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const offline = CPLHttpNoInternetConnectionException();
    var wave = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          coupleProvider.overrideWith((ref) async {
            if (wave == 0) throw offline;
            return _couple;
          }),
          currentMoodProvider.overrideWith((ref) async {
            if (wave == 0) throw offline;
            return MoodCurrent(
              me: MoodSnapshot(
                mood: MoodLevel.good,
                createdAt: DateTime.utc(2026, 10, 1),
                stale: false,
              ),
              partner: MoodSnapshot(
                mood: MoodLevel.bad,
                createdAt: DateTime.utc(2026, 10, 1),
                stale: false,
              ),
            );
          }),
          nextDateProvider.overrideWith((ref) async {
            if (wave == 0) throw offline;
            return null;
          }),
          todayQuestionProvider.overrideWith((ref) async {
            if (wave == 0) throw offline;
            return null;
          }),
          feedPreviewProvider.overrideWith((ref) async {
            if (wave == 0) throw offline;
            return const <ActivityEvent>[];
          }),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(offlineHomeNoticeKey), findsOneWidget);
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(find.text(homeMoodLoadError), findsOneWidget);
    expect(find.text(homeDatesLoadError), findsOneWidget);
    expect(find.text(homeDaysLoadError), findsOneWidget);
    expect(find.text(homeQuestionLoadError), findsOneWidget);
    expect(find.text(homeFeedLoadError), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(tester.getSize(find.byType(MoodHomeCard)).height, homeMoodCardHeight);

    final daysError = find.widgetWithText(LoadErrorCard, homeDaysLoadError);
    expect(tester.getSize(daysError).height, homeDaysCardHeight);
    expect(
      tester.getSize(find.widgetWithText(LoadErrorCard, homeMoodLoadError)).height,
      homeMoodCardHeight,
    );
    final careBefore = tester.getTopLeft(find.text('Nossas listas')).dy;

    wave = 1;
    await tester.tap(
      find.descendant(of: daysError, matching: find.text('Tentar de novo')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(offlineHomeNoticeKey), findsNothing);
    expect(find.text(offlineUserMessage), findsNothing);
    expect(find.byType(LoadErrorCard), findsNothing);
    expect(find.text('7 dias juntos'), findsOneWidget);
    expect(find.text('Como vocês estão'), findsOneWidget);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(tester.getSize(find.byType(DaysTogetherCard)).height, homeDaysCardHeight);
    expect(tester.getSize(find.byType(MoodHomeCard)).height, homeMoodCardHeight);
    expect(tester.getTopLeft(find.text('Nossas listas')).dy, careBefore);
  });

  testWidgets('cold offline still shows the bell and dias juntos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_OfflineSession.new),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: lightTheme, home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(find.text(homeDaysLoadError), findsOneWidget);
    expect(find.text(offlineUserMessage), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(LoadErrorCard, homeDaysLoadError)).height, homeDaysCardHeight);
    expect(find.byType(LoadErrorCard), findsNWidgets(5));
  });

  testWidgets('list rows and carinho stay put at 360x640', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _ListsRepo([_list()]);
    repo.failToggle = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _Session(_ada)),
          listsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: ListDetailPage(listId: 'list-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.text('Café');
    final before = tester.getTopLeft(row).dy;
    expect(tester.getSize(find.byKey(const Key('list-item-i2'))).height, listItemSlotHeight);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.getTopLeft(row).dy, before);

    repo.failToggle = false;
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(row).dy, before);
    expect(tester.getSize(find.byKey(const Key('list-item-i2'))).height, listItemSlotHeight);
  });
}
Rect _globalSemanticsRect(SemanticsNode node) {
  var rect = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
    current = current.parent;
  }
  return rect;
}

SemanticsNode? _hitSemantics(WidgetTester tester, Offset global) {
  final physical = global * tester.view.devicePixelRatio;
  SemanticsNode? hit(SemanticsNode node) {
    final children = <SemanticsNode>[];
    node.visitChildren((child) {
      children.add(child);
      return true;
    });
    for (final child in children.reversed) {
      final found = hit(child);
      if (found != null) return found;
    }
    if (node.isMergedIntoParent) return null;
    final data = node.getSemanticsData();
    if (data.flagsCollection.isHidden ||
        !_globalSemanticsRect(node).contains(physical)) {
      return null;
    }
    final flags = data.flagsCollection;
    final absorbs =
        flags.isTextField ||
        flags.isButton ||
        flags.isFocusable ||
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.setText) ||
        data.hasAction(SemanticsAction.focus);
    if (!absorbs) return null;
    return node;
  }

  final roots = <SemanticsNode>[];
  void collect(PipelineOwner owner) {
    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) roots.add(root);
    owner.visitChildren(collect);
  }

  collect(tester.binding.rootPipelineOwner);
  for (final root in roots.reversed) {
    final found = hit(root);
    if (found != null) return found;
  }
  return null;
}
