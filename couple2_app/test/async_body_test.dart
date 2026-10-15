import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading shows a skeleton instead of the child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AsyncBody(
          isLoading: true,
          child: Text('dados'),
        ),
      ),
    );

    expect(find.byType(ListSkeleton), findsOneWidget);
    expect(find.text('dados'), findsNothing);
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('error shows a retry action and empty shows the message', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorView(
          message: 'Falhou',
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('Falhou'), findsOneWidget);
    await tester.tap(find.byKey(ErrorView.retryKey));
    await tester.pump();
    expect(retries, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: EmptyView(message: 'Vazio'),
      ),
    );
    expect(find.text('Vazio'), findsOneWidget);
    expect(find.byKey(EmptyView.emptyKey), findsOneWidget);
  });

  testWidgets('AsyncValueView keeps data and skips the skeleton on reload', (
    tester,
  ) async {
    final provider = FutureProvider<List<String>>((ref) async => ['um']);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return AsyncValueView<List<String>>(
                value: ref.watch(provider),
                isEmpty: (items) => items.isEmpty,
                data: (items) => Text(items.join(',')),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pump();
    await tester.pump();
    expect(find.text('um'), findsOneWidget);
    expect(find.byType(ListSkeleton), findsNothing);
  });
}
