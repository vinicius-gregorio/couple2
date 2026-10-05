import 'entities/couple.dart';

String daysTogetherLabel(int days) => '$days dias juntos';

String nextDateLine(UpcomingDate next) {
  final when = switch (next.inDays) {
    0 => 'hoje',
    1 => 'em 1 dia',
    _ => 'em ${next.inDays} dias',
  };
  final subject = switch (next.kind) {
    'birthday' => 'aniversário de ${next.title}',
    'anniversary' => 'aniversário de namoro',
    _ => next.title,
  };
  return 'Próxima data: $subject $when';
}
