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
      feedActorLabel(
        actorId: 'bob',
        currentUserId: 'ada',
        actorName: 'Bob',
      ),
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
    expect(
      activityRoute('COUPLE_DATE_UPCOMING', const {}),
      '/couple/dates',
    );
  });
}
