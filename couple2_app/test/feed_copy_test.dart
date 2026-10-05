import 'package:couple2_app/modules/feed/domain/feed_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds feed text from the payload snapshot', () {
    expect(
      feedActionText('LIST_ITEM_COMPLETED', {
        'listName': 'Compras',
        'content': 'leite',
      }),
      'concluiu "leite" em "Compras"',
    );
    expect(
      feedActionText('COUPLE_DATE_UPCOMING', {
        'title': 'Aniversário de Bob',
        'inDays': 7,
      }),
      'Aniversário de Bob é em 7 dias',
    );
    expect(
      feedActorLabel(actorId: 'bob', currentUserId: 'ada', actorName: 'Bob'),
      'Bob',
    );
    expect(
      feedActorLabel(actorId: 'ada', currentUserId: 'ada', actorName: 'Ada'),
      'Você',
    );
    expect(
      feedActorLabel(actorId: null, currentUserId: 'ada', actorName: null),
      'Lembrete',
    );
  });

  test('opens the list or the dates screen from the snapshot', () {
    expect(
      activityRoute('LIST_ITEM_ADDED', {'listId': 'list-1'}),
      '/lists/list-1',
    );
    expect(activityRoute('COUPLE_DATE_UPCOMING', const {}), '/couple/dates');
    expect(
      feedActionText('QUESTION_ANSWERED', const {}),
      'respondeu a pergunta do dia',
    );
    expect(
      feedActionText('QUESTION_UNLOCKED', const {}),
      'desbloqueou a pergunta do dia',
    );
    expect(activityRoute('QUESTION_UNLOCKED', const {}), '/question');
    expect(
      feedActionText('MOOD_SHARED', {'mood': 'LOW', 'note': 'segredo'}),
      'não está num dia muito bom',
    );
    expect(
      feedActionText('MOOD_SHARED', {'mood': 'GOOD'}),
      'compartilhou como está',
    );
    expect(
      feedActionText('NUDGE_SENT', {'message': 'oi'}),
      'mandou um carinho: "oi"',
    );
    expect(activityRoute('MOOD_SHARED', const {}), '/mood/history');
    expect(activityRoute('NUDGE_SENT', const {}), '/nudges');
  });
}
