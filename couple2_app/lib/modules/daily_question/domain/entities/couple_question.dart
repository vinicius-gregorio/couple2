class QuestionAnswer {
  const QuestionAnswer({
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      text: json['text'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class QuestionPrompt {
  const QuestionPrompt({required this.text, required this.category});

  final String text;
  final String category;

  factory QuestionPrompt.fromJson(Map<String, dynamic> json) {
    return QuestionPrompt(
      text: json['text'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'category': category};
}

class CoupleQuestion {
  const CoupleQuestion({
    required this.id,
    required this.date,
    required this.question,
    required this.partnerAnswered,
    required this.answerable,
    this.myAnswer,
    this.unlockedAt,
    this.partnerAnswer,
  });

  final String id;
  final String date;
  final QuestionPrompt question;
  final QuestionAnswer? myAnswer;
  final bool partnerAnswered;
  final DateTime? unlockedAt;
  final bool answerable;

  /// Only present after unlock. A missing key means the partner text was not sent.
  final QuestionAnswer? partnerAnswer;

  bool get unlocked => unlockedAt != null;
  bool get answeredByMe => myAnswer != null;

  factory CoupleQuestion.fromJson(Map<String, dynamic> json) {
    final myAnswer = json['myAnswer'];
    final partnerAnswer = json['partnerAnswer'];
    final unlockedAt = json['unlockedAt'];
    return CoupleQuestion(
      id: json['id'] as String,
      date: json['date'] as String,
      question: QuestionPrompt.fromJson(
        Map<String, dynamic>.from(json['question'] as Map),
      ),
      myAnswer: myAnswer is Map
          ? QuestionAnswer.fromJson(Map<String, dynamic>.from(myAnswer))
          : null,
      partnerAnswered: json['partnerAnswered'] as bool? ?? false,
      unlockedAt: unlockedAt is String ? DateTime.parse(unlockedAt) : null,
      answerable: json['answerable'] as bool? ?? false,
      partnerAnswer: partnerAnswer is Map
          ? QuestionAnswer.fromJson(Map<String, dynamic>.from(partnerAnswer))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'question': question.toJson(),
    'myAnswer': myAnswer?.toJson(),
    'partnerAnswered': partnerAnswered,
    'unlockedAt': unlockedAt?.toUtc().toIso8601String(),
    'answerable': answerable,
    'partnerAnswer': partnerAnswer?.toJson(),
  };
}

class QuestionHistoryPageResult {
  const QuestionHistoryPageResult({required this.items, this.nextCursor});

  final List<CoupleQuestion> items;
  final String? nextCursor;

  factory QuestionHistoryPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (entry) =>
                    CoupleQuestion.fromJson(Map<String, dynamic>.from(entry)),
              )
              .toList()
        : <CoupleQuestion>[];
    final cursor = json['nextCursor'];
    return QuestionHistoryPageResult(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
