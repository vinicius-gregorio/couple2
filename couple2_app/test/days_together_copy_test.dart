import 'package:couple2_app/modules/couple/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home card copy matches the couple record spec', () {
    expect(daysTogetherLabel(731), '731 dias juntos');
    expect(
      nextDateLine(
        const UpcomingDate(
          kind: 'birthday',
          title: 'B',
          date: '2026-10-17',
          inDays: 12,
        ),
      ),
      'Próxima data: aniversário de B em 12 dias',
    );
    expect(
      nextDateLine(
        const UpcomingDate(
          kind: 'anniversary',
          title: 'Aniversário de namoro',
          date: '2026-10-05',
          inDays: 0,
        ),
      ),
      'Próxima data: aniversário de namoro hoje',
    );
    expect(
      nextDateLine(
        const UpcomingDate(
          kind: 'custom',
          title: 'Primeiro beijo',
          date: '2026-10-06',
          inDays: 1,
        ),
      ),
      'Próxima data: Primeiro beijo em 1 dia',
    );
  });
}
