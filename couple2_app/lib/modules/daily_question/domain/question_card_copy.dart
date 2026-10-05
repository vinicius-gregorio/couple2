enum TodayCardKind { unanswered, waiting, unlocked }

class TodayCardCopy {
  const TodayCardCopy({
    required this.kind,
    required this.title,
    required this.grayPartnerAvatar,
  });

  final TodayCardKind kind;
  final String title;
  final bool grayPartnerAvatar;
}

/// Home card copy for the three question states.
TodayCardCopy todayCardCopy({
  required bool answeredByMe,
  required bool unlocked,
  required String partnerName,
}) {
  final name = partnerName.trim().isEmpty ? 'seu par' : partnerName.trim();
  if (unlocked) {
    return TodayCardCopy(
      kind: TodayCardKind.unlocked,
      title: 'Desbloqueada! Veja a resposta de $name',
      grayPartnerAvatar: false,
    );
  }
  if (answeredByMe) {
    return TodayCardCopy(
      kind: TodayCardKind.waiting,
      title: 'Você respondeu, aguardando $name',
      grayPartnerAvatar: true,
    );
  }
  return const TodayCardCopy(
    kind: TodayCardKind.unanswered,
    title: 'Responda a pergunta de hoje',
    grayPartnerAvatar: false,
  );
}

/// Pending rows from the last 7 days that this person has not answered yet.
bool showHistoryAnswerCta({
  required bool answerable,
  required bool answeredByMe,
}) {
  return answerable && !answeredByMe;
}

bool showHistoryEditCta({
  required bool answerable,
  required bool answeredByMe,
  required bool unlocked,
}) {
  return answerable && answeredByMe && !unlocked;
}

String questionCategoryLabel(String category) {
  switch (category) {
    case 'FUN':
      return 'Diversão';
    case 'DEEP':
      return 'Profunda';
    case 'MEMORIES':
      return 'Memórias';
    case 'FUTURE':
      return 'Futuro';
    case 'DAILY_LIFE':
      return 'Dia a dia';
    default:
      return category;
  }
}

/// Formats a `YYYY-MM-DD` calendar date without shifting it through UTC.
String formatCalendarDate(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
