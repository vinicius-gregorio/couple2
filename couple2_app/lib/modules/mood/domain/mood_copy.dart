import 'entities/mood_checkin.dart';

/// "há 2 h". Warm and plain. No streak, no "you missed today".
String moodAgeLabel(DateTime createdAt, [DateTime? now]) {
  final clock = now ?? DateTime.now();
  final delta = clock.difference(createdAt);
  if (delta.isNegative || delta.inMinutes < 1) return 'agora';
  if (delta.inMinutes < 60) return 'há ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'há ${delta.inHours} h';
  return 'há ${delta.inDays} d';
}

String moodDayLabel(DateTime createdAt, [DateTime? now]) {
  final clock = now ?? DateTime.now();
  final local = createdAt.toLocal();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${local.day} ${months[local.month - 1]}';
}

bool suggestCaringNudge(MoodLevel? mood) => mood?.caring ?? false;

String nudgeRateLimitMessage() {
  return 'Vamos com calma. Você pode mandar outro carinho daqui a pouco.';
}
