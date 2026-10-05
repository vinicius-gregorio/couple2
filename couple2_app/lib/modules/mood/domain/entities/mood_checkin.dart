enum MoodLevel {
  great('GREAT', '😄', 'Muito bem'),
  good('GOOD', '🙂', 'Bem'),
  ok('OK', '😐', 'Na medida'),
  low('LOW', '😔', 'Mais ou menos'),
  bad('BAD', '😢', 'Dia difícil');

  const MoodLevel(this.apiValue, this.emoji, this.label);

  final String apiValue;
  final String emoji;
  final String label;

  static MoodLevel? parse(Object? value) {
    if (value is! String) return null;
    for (final level in MoodLevel.values) {
      if (level.apiValue == value) return level;
    }
    return null;
  }

  bool get caring => this == MoodLevel.low || this == MoodLevel.bad;
}

class MoodSnapshot {
  const MoodSnapshot({
    required this.mood,
    required this.createdAt,
    required this.stale,
    this.note,
  });

  final MoodLevel mood;
  final String? note;
  final DateTime createdAt;
  final bool stale;

  factory MoodSnapshot.fromJson(Map<String, dynamic> json) {
    final mood = MoodLevel.parse(json['mood']);
    if (mood == null) {
      throw FormatException('Humor desconhecido');
    }
    return MoodSnapshot(
      mood: mood,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stale: json['stale'] as bool? ?? false,
    );
  }
}

class MoodCurrent {
  const MoodCurrent({this.me, this.partner});

  final MoodSnapshot? me;
  final MoodSnapshot? partner;

  factory MoodCurrent.fromJson(Map<String, dynamic> json) {
    final me = json['me'];
    final partner = json['partner'];
    return MoodCurrent(
      me: me is Map
          ? MoodSnapshot.fromJson(Map<String, dynamic>.from(me))
          : null,
      partner: partner is Map
          ? MoodSnapshot.fromJson(Map<String, dynamic>.from(partner))
          : null,
    );
  }
}

class MoodCheckin {
  const MoodCheckin({
    required this.id,
    required this.userId,
    required this.mood,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String userId;
  final MoodLevel mood;
  final String? note;
  final DateTime createdAt;

  factory MoodCheckin.fromJson(Map<String, dynamic> json) {
    final mood = MoodLevel.parse(json['mood']);
    if (mood == null) {
      throw FormatException('Humor desconhecido');
    }
    return MoodCheckin(
      id: json['id'] as String,
      userId: json['userId'] as String,
      mood: mood,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class MoodHistory {
  const MoodHistory({required this.days, required this.items});

  final int days;
  final List<MoodCheckin> items;

  factory MoodHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => MoodCheckin.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <MoodCheckin>[];
    return MoodHistory(days: json['days'] as int? ?? 30, items: items);
  }
}
