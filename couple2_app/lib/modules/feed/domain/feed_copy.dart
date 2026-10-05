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
  return null;
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
