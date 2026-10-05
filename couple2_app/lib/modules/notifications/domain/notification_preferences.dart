class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.lists,
    required this.importantDates,
    required this.dailyQuestion,
    required this.mood,
    required this.nudges,
    required this.datePlans,
    this.quietStartMin,
    this.quietEndMin,
  });

  final bool pushEnabled;
  final bool lists;
  final bool importantDates;
  final bool dailyQuestion;
  final bool mood;
  final bool nudges;
  final bool datePlans;
  final int? quietStartMin;
  final int? quietEndMin;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      lists: json['lists'] as bool? ?? true,
      importantDates: json['importantDates'] as bool? ?? true,
      dailyQuestion: json['dailyQuestion'] as bool? ?? true,
      mood: json['mood'] as bool? ?? true,
      nudges: json['nudges'] as bool? ?? true,
      datePlans: json['datePlans'] as bool? ?? true,
      quietStartMin: json['quietStartMin'] as int?,
      quietEndMin: json['quietEndMin'] as int?,
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? lists,
    bool? importantDates,
    bool? dailyQuestion,
    bool? mood,
    bool? nudges,
    bool? datePlans,
    int? quietStartMin,
    int? quietEndMin,
    bool clearQuiet = false,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      lists: lists ?? this.lists,
      importantDates: importantDates ?? this.importantDates,
      dailyQuestion: dailyQuestion ?? this.dailyQuestion,
      mood: mood ?? this.mood,
      nudges: nudges ?? this.nudges,
      datePlans: datePlans ?? this.datePlans,
      quietStartMin: clearQuiet ? null : (quietStartMin ?? this.quietStartMin),
      quietEndMin: clearQuiet ? null : (quietEndMin ?? this.quietEndMin),
    );
  }
}

/// Minutes from local midnight. 1380 is 23:00.
int quietMinutes(int hour, int minute) => hour * 60 + minute;

String formatQuietMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
