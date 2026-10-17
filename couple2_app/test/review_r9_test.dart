import 'dart:io';

import 'package:couple2_app/core/errors/user_facing_error.dart';
import 'package:couple2_app/core/external/http_client/exceptions/exceptions.dart';
import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib buttons stay inside the three theme components', () {
    final pattern = RegExp(
      r'ElevatedButton|OutlinedButton|TextButton|FilledButton|ButtonStyle|styleFrom',
    );
    const allow = {
      'lib/design_system/widgets/loading_button.dart',
      'lib/design_system/theme/button_themes.dart',
    };
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      final rel = normalized.substring(normalized.indexOf('lib/'));
      if (allow.contains(rel)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('$rel:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('one mapper separates offline, server, and validation', () {
    expect(
      userFacingError(const CPLHttpNoInternetConnectionException()),
      offlineUserMessage,
    );
    expect(
      userFacingError(
        const CPLHttpInternalServerErrorException(message: 'boom'),
      ),
      'O servidor não respondeu. Tente de novo.',
    );
    expect(
      userFacingError(
        const CPLHttpBadRequestException(message: 'invalid title'),
      ),
      'Não deu para salvar. Confira os dados.',
    );
    expect(
      userFacingError(
        const CPLHttpNoInternetConnectionException(),
        fallback: 'Não foi possível enviar a resposta.',
      ),
      offlineUserMessage,
    );
  });

  testWidgets('previous month control has a PT-BR name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: LoadingButton(
                onPressed: () {
                  showAppDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 6, 15),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2026, 12, 31),
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mês anterior'), findsOneWidget);
  });
}
