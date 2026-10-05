enum DatePlanStatus {
  proposed,
  accepted,
  declined,
  cancelled,
  done,
  expired;

  static DatePlanStatus? parse(String? raw) {
    switch (raw) {
      case 'PROPOSED':
        return DatePlanStatus.proposed;
      case 'ACCEPTED':
        return DatePlanStatus.accepted;
      case 'DECLINED':
        return DatePlanStatus.declined;
      case 'CANCELLED':
        return DatePlanStatus.cancelled;
      case 'DONE':
        return DatePlanStatus.done;
      case 'EXPIRED':
        return DatePlanStatus.expired;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case DatePlanStatus.proposed:
        return 'Proposto';
      case DatePlanStatus.accepted:
        return 'Confirmado';
      case DatePlanStatus.declined:
        return 'Recusado';
      case DatePlanStatus.cancelled:
        return 'Cancelado';
      case DatePlanStatus.done:
        return 'Feito';
      case DatePlanStatus.expired:
        return 'Expirado';
    }
  }
}

class DatePlanSourceItem {
  const DatePlanSourceItem({
    required this.id,
    required this.content,
    required this.isCompleted,
    required this.listType,
    required this.listId,
  });

  final String id;
  final String content;
  final bool isCompleted;
  final String listType;
  final String listId;

  factory DatePlanSourceItem.fromJson(Map<String, dynamic> json) {
    return DatePlanSourceItem(
      id: json['id'] as String,
      content: json['content'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      listType: json['listType'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
    );
  }
}

class DatePlan {
  const DatePlan({
    required this.id,
    required this.coupleId,
    required this.proposerId,
    required this.title,
    required this.scheduledAt,
    required this.status,
    required this.createdById,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.location,
    this.responseNote,
    this.respondedAt,
    this.completedAt,
    this.reminderSentAt,
    this.sourceListItemId,
    this.sourceListItem,
  });

  final String id;
  final String coupleId;
  final String proposerId;
  final String title;
  final String? description;
  final String? location;
  final DateTime scheduledAt;
  final DatePlanStatus status;
  final String? responseNote;
  final DateTime? respondedAt;
  final DateTime? completedAt;
  final DateTime? reminderSentAt;
  final String? sourceListItemId;
  final DatePlanSourceItem? sourceListItem;
  final String createdById;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get sourceRemoved => sourceListItemId != null && sourceListItem == null;

  bool canAccept(String me) =>
      status == DatePlanStatus.proposed && proposerId != me;

  bool canDecline(String me) => canAccept(me);

  bool canCounter(String me) => canAccept(me);

  bool canEdit(String me) =>
      status == DatePlanStatus.proposed && proposerId == me;

  bool canCancel(String me) =>
      (status == DatePlanStatus.proposed && proposerId == me) ||
      status == DatePlanStatus.accepted;

  bool canDone(String me) => status == DatePlanStatus.accepted;

  factory DatePlan.fromJson(Map<String, dynamic> json) {
    final status = DatePlanStatus.parse(json['status'] as String?);
    if (status == null) {
      throw const FormatException('Resposta de date inválida');
    }
    final source = json['sourceListItem'];
    return DatePlan(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      proposerId: json['proposerId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: status,
      responseNote: json['responseNote'] as String?,
      respondedAt: _date(json['respondedAt']),
      completedAt: _date(json['completedAt']),
      reminderSentAt: _date(json['reminderSentAt']),
      sourceListItemId: json['sourceListItemId'] as String?,
      sourceListItem: source is Map<String, dynamic>
          ? DatePlanSourceItem.fromJson(source)
          : source is Map
          ? DatePlanSourceItem.fromJson(Map<String, dynamic>.from(source))
          : null,
      createdById: json['createdById'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class DatePlanPage {
  const DatePlanPage({required this.items, this.nextCursor});

  final List<DatePlan> items;
  final String? nextCursor;

  factory DatePlanPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
              .whereType<Map>()
              .map((item) => DatePlan.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <DatePlan>[];
    final cursor = json['nextCursor'];
    return DatePlanPage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value);
}

/// Device-local civil time as an ISO-8601 string with a numeric offset or Z.
String isoWithOffset(DateTime local) {
  String two(int value) => value.abs().toString().padLeft(2, '0');
  final y = local.year.toString().padLeft(4, '0');
  final date =
      '$y-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  final offset = local.timeZoneOffset;
  if (offset.inMinutes == 0) return '${date}Z';
  final sign = offset.isNegative ? '-' : '+';
  final hours = two(offset.inHours);
  final minutes = two(offset.inMinutes.abs() % 60);
  return '$date$sign$hours:$minutes';
}
