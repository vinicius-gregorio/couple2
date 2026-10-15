import 'dart:io';
import 'dart:ui' as ui;

import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/app/session_provider.dart';
import 'package:couple2_app/app/ui/pages/home/home_page.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:couple2_app/modules/couple/data/couple_providers.dart';
import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:couple2_app/modules/daily_question/data/daily_question_providers.dart';
import 'package:couple2_app/modules/date_plans/data/date_plans_providers.dart';
import 'package:couple2_app/modules/feed/data/feed_providers.dart';
import 'package:couple2_app/modules/mood/data/mood_providers.dart';
import 'package:couple2_app/modules/mood/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _primary = Color(0xFF9D174D);
const _white = Color(0xFFFFFFFF);
const _disabledFill = Color(0xFFE4DEE1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lib has no FilledButton.tonal or ElevatedButton', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('FilledButton.tonal') ||
          source.contains('ElevatedButton')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
  });

  testWidgets('home buttons stay inside the three theme variants', (
    tester,
  ) async {
    await _size(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_PairedSession.new),
          coupleProvider.overrideWith((ref) async => _couple),
          currentMoodProvider.overrideWith((ref) async => _mood),
          nextDateProvider.overrideWith((ref) async => null),
          todayQuestionProvider.overrideWith((ref) async => null),
          feedPreviewProvider.overrideWith((ref) async => const []),
          unreadCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: const RepaintBoundary(child: HomePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Nossas listas'), findsOneWidget);
    expect(find.text('Our Lists'), findsNothing);
    expect(find.text('Planejar um date'), findsOneWidget);
    expect(find.text('💗 Pensando em você'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Carinhos recebidos'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.byType(OutlinedButton), findsWidgets);
    expect(find.byType(TextButton), findsWidgets);

    _expectAllowedButtons(tester);
    await _saveHome(tester, 'home-after');
  });

  testWidgets('disabled and selected controls use the theme colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          body: ListView(
            children: [
              const FilledButton(onPressed: null, child: Text('Off')),
              const OutlinedButton(onPressed: null, child: Text('Off line')),
              const TextButton(onPressed: null, child: Text('Off text')),
              FilledButton(onPressed: () {}, child: const Text('On')),
              ChoiceChip(
                label: const Text('Ocasião'),
                selected: true,
                onSelected: (_) {},
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back)),
              const IconButton(onPressed: null, icon: Icon(Icons.close)),
              LoadingIconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline),
              ),
              const LoadingIconButton(
                onPressed: null,
                icon: Icon(Icons.delete_outline),
              ),
              Switch(value: true, onChanged: (_) {}),
              Checkbox(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ElevatedButton), findsNothing);
    _expectAllowedButtons(tester);

    final ink = tester.widget<Ink>(
      find
          .descendant(
            of: find.byType(ChoiceChip),
            matching: find.byType(Ink),
          )
          .first,
    );
    expect((ink.decoration! as ShapeDecoration).color, _primary);
    final theme = Theme.of(tester.element(find.byType(Switch)));
    expect(
      theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
      _primary,
    );
    expect(theme.checkboxTheme.side?.color, _primary);
    expect(theme.iconButtonTheme.style, isNotNull);
    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Ocasião')),
      ).style.color,
      _white,
    );
  });
}

void _expectAllowedButtons(WidgetTester tester) {
  final disabledFg = lightColorScheme.onSurface.withValues(alpha: 0.38);
  final buttons = find.byWidgetPredicate(
    (widget) =>
        widget is FilledButton ||
        widget is OutlinedButton ||
        widget is TextButton ||
        widget is FloatingActionButton ||
        widget is IconButton,
  );

  for (final element in buttons.evaluate()) {
    final widget = element.widget;
    expect(widget, isNot(isA<ElevatedButton>()));
    if (widget is IconButton) {
      _expectIconButton(tester, widget, disabledFg);
      continue;
    }
    final background = _background(tester, widget);
    final foreground = _foreground(tester, widget);
    if (background != null && background.a > 0) {
      expect(
        background == _primary || background == _disabledFill,
        isTrue,
        reason: '$widget fill $background',
      );
    }
    if (foreground != null) {
      expect(
        foreground == _white ||
            foreground == _primary ||
            foreground == disabledFg,
        isTrue,
        reason: '$widget label $foreground',
      );
    }
  }
}

void _expectIconButton(
  WidgetTester tester,
  IconButton button,
  Color disabledFg,
) {
  final icons = find.descendant(
    of: find.byWidget(button),
    matching: find.byType(Icon),
  );
  expect(icons, findsWidgets, reason: 'IconButton has no glyph');
  final icon = tester.widget<Icon>(icons.first);
  final color =
      icon.color ?? IconTheme.of(tester.element(icons.first)).color;
  final background = _background(tester, button);
  final filled = background != null && background.a > 0.5;
  final disabled = button.onPressed == null;
  if (filled) {
    expect(
      background,
      disabled ? _disabledFill : _primary,
      reason: 'filled icon fill $background',
    );
    expect(color, disabled ? disabledFg : _white, reason: 'filled icon $color');
  } else {
    expect(
      color,
      disabled ? disabledFg : _primary,
      reason: 'icon glyph $color',
    );
  }
}

Color? _background(WidgetTester tester, Widget widget) {
  final materials = find.descendant(
    of: find.byWidget(widget),
    matching: find.byType(Material),
  );
  if (materials.evaluate().isEmpty) return null;
  return tester.widget<Material>(materials.first).color;
}

Color? _foreground(WidgetTester tester, Widget widget) {
  final texts = find.descendant(
    of: find.byWidget(widget),
    matching: find.byType(Text),
  );
  if (texts.evaluate().isNotEmpty) {
    return DefaultTextStyle.of(texts.evaluate().first).style.color;
  }
  final icons = find.descendant(
    of: find.byWidget(widget),
    matching: find.byType(Icon),
  );
  if (icons.evaluate().isEmpty) return null;
  final icon = tester.widget<Icon>(icons.first);
  return icon.color ?? IconTheme.of(icons.evaluate().first).color;
}

Future<void> _size(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _saveHome(WidgetTester tester, String name) async {
  final dir = Directory('/opt/cursor/artifacts');
  if (!dir.existsSync()) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${dir.path}/$name.png').writeAsBytesSync(
      bytes!.buffer.asUint8List(),
    );
  });
}

class _PairedSession extends SessionNotifier {
  @override
  Future<Session?> build() async {
    return const Session(
      id: 'ada',
      email: 'ada@example.com',
      name: 'Ada',
      isPaired: true,
      coupleId: 'couple-1',
      partnerName: 'Bruno',
    );
  }
}

final _couple = Couple(
  id: 'couple-1',
  pairedAt: DateTime.utc(2024, 1, 1),
  anniversaryDate: '2024-01-01',
  timezone: 'America/Sao_Paulo',
  daysTogether: 650,
  partner: const CouplePartner(id: 'bruno', name: 'Bruno'),
  upcoming: const [],
);

final _mood = MoodCurrent(
  me: MoodSnapshot(
    mood: MoodLevel.good,
    createdAt: DateTime.now(),
    stale: false,
  ),
  partner: MoodSnapshot(
    mood: MoodLevel.low,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    stale: false,
  ),
);
