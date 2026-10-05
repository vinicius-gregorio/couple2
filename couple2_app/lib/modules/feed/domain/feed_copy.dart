/// Text built from the activity snapshot. The payload is what was true when
/// the event was written, even if the item was later deleted.
String feedActionText(String type, Map<String, dynamic>? payload) {
  final data = payload ?? const <String, dynamic>{};
  final listName = _text(data['listName']) ?? 'uma lista';
  final content = _text(data['content']);
  final title = _text(data['title']) ?? 'Data importante';
  final inDays = data['inDays'];

  switch (type) {
    case 'LIST_CREATED':
      return 'criou a lista "$listName"';
    case 'LIST_ITEM_ADDED':
      return content == null
          ? 'adicionou um item em "$listName"'
          : 'adicionou "$content" em "$listName"';
    case 'LIST_ITEM_COMPLETED':
      return content == null
          ? 'concluiu um item em "$listName"'
          : 'concluiu "$content" em "$listName"';
    case 'COUPLE_DATE_UPCOMING':
      return '$title ${_whenLabel(inDays)}';
    case 'COUPLE_UPDATED':
      return 'atualizou o casal';
    case 'QUESTION_ANSWERED':
      return 'respondeu a pergunta do dia';
    case 'QUESTION_UNLOCKED':
      return 'desbloqueou a pergunta do dia';
    case 'MOOD_SHARED':
      final mood = data['mood'];
      if (mood == 'LOW' || mood == 'BAD') {
        return 'não está num dia muito bom';
      }
      return 'compartilhou como está';
    case 'NUDGE_SENT':
      final message = _text(data['message']);
      return message == null
          ? 'mandou um carinho'
          : 'mandou um carinho: "$message"';
    case 'DATE_PLAN_PROPOSED':
      return _datePlanText('propôs o date', title, data);
    case 'DATE_PLAN_ACCEPTED':
      return 'aceitou o date "$title"';
    case 'DATE_PLAN_DECLINED':
      return 'recusou o date "$title"';
    case 'DATE_PLAN_COUNTERED':
      return _datePlanText('sugeriu', title, data);
    case 'DATE_PLAN_CANCELLED':
      return 'cancelou o date "$title"';
    case 'DATE_PLAN_DONE':
      return 'marcou o date "$title" como feito';
    default:
      return 'fez uma atualização';
  }
}

String feedActorLabel({
  required String? actorId,
  required String? currentUserId,
  required String? actorName,
}) {
  if (actorId == null) return 'Lembrete';
  if (actorId == currentUserId) return 'Você';
  final name = actorName?.trim();
  return (name == null || name.isEmpty) ? 'Parceiro' : name;
}

String? activityRoute(String type, Map<String, dynamic>? payload) {
  final data = payload ?? const <String, dynamic>{};
  final route = data['route'];
  if (route is String && route.isNotEmpty) return route;
  final listId = data['listId'];
  if (listId is String && listId.isNotEmpty) return '/lists/$listId';
  if (type == 'COUPLE_DATE_UPCOMING' || type == 'COUPLE_UPDATED') {
    return '/couple/dates';
  }
  if (type == 'QUESTION_ANSWERED' || type == 'QUESTION_UNLOCKED') {
    return '/question';
  }
  if (type == 'MOOD_SHARED') return '/mood/history';
  if (type == 'NUDGE_SENT') return '/nudges';
  if (type.startsWith('DATE_PLAN_')) return '/dates';
  return null;
}

String _datePlanText(String verb, String title, Map<String, dynamic> data) {
  final when = _text(data['whenLabel']);
  if (when == null) return '$verb "$title"';
  return '$verb "$title" para $when';
}

String _whenLabel(Object? inDays) {
  if (inDays == 0) return 'é hoje';
  if (inDays == 1) return 'é amanhã';
  if (inDays is num) return 'é em ${inDays.toInt()} dias';
  return 'está chegando';
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
