enum NudgeKind {
  thinkingOfYou('THINKING_OF_YOU', '💗', 'Pensando em você'),
  hug('HUG', '🤗', 'Abraço'),
  kiss('KISS', '💋', 'Beijo'),
  missYou('MISS_YOU', '🌙', 'Saudade');

  const NudgeKind(this.apiValue, this.emoji, this.label);

  final String apiValue;
  final String emoji;
  final String label;

  static NudgeKind? parse(Object? value) {
    if (value is! String) return null;
    for (final kind in NudgeKind.values) {
      if (kind.apiValue == value) return kind;
    }
    return null;
  }
}

class Nudge {
  const Nudge({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.kind,
    required this.createdAt,
    this.message,
    this.seenAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final NudgeKind kind;
  final String? message;
  final DateTime? seenAt;
  final DateTime createdAt;

  bool get seen => seenAt != null;

  factory Nudge.fromJson(Map<String, dynamic> json) {
    final kind = NudgeKind.parse(json['kind']);
    if (kind == null) {
      throw FormatException('Carinho desconhecido');
    }
    final seenAt = json['seenAt'];
    return Nudge(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      kind: kind,
      message: json['message'] as String?,
      seenAt: seenAt is String ? DateTime.parse(seenAt) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class NudgePage {
  const NudgePage({required this.items, this.nextCursor});

  final List<Nudge> items;
  final String? nextCursor;

  factory NudgePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Nudge.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : const <Nudge>[];
    final cursor = json['nextCursor'];
    return NudgePage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
