class CoupleDate {
  const CoupleDate({
    required this.id,
    required this.coupleId,
    required this.type,
    required this.title,
    required this.date,
    required this.recurrence,
    required this.createdById,
  });

  final String id;
  final String coupleId;
  final String type;
  final String title;
  final String date;
  final String recurrence;
  final String createdById;

  factory CoupleDate.fromJson(Map<String, dynamic> json) {
    return CoupleDate(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      recurrence: json['recurrence'] as String,
      createdById: json['createdById'] as String,
    );
  }

  CoupleDate copyWith({
    String? title,
    String? date,
    String? recurrence,
  }) {
    return CoupleDate(
      id: id,
      coupleId: coupleId,
      type: type,
      title: title ?? this.title,
      date: date ?? this.date,
      recurrence: recurrence ?? this.recurrence,
      createdById: createdById,
    );
  }
}
