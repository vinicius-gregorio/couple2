class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.coupleId,
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.actorId,
    this.payload = const {},
  });

  final String id;
  final String coupleId;
  final String? actorId;
  final String type;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return ActivityEvent(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      actorId: json['actorId'] as String?,
      type: json['type'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
              ? Map<String, dynamic>.from(rawPayload)
              : const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FeedPageResult {
  const FeedPageResult({required this.items, this.nextCursor});

  final List<ActivityEvent> items;
  final String? nextCursor;

  factory FeedPageResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((entry) => ActivityEvent.fromJson(Map<String, dynamic>.from(entry)))
            .toList()
        : <ActivityEvent>[];
    final cursor = json['nextCursor'];
    return FeedPageResult(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
