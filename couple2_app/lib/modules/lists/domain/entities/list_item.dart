class ListItem {
  final String id;
  final String listId;
  final String content;
  final Map<String, dynamic>? metadata;
  final bool isCompleted;
  final String addedById;
  final DateTime createdAt;

  const ListItem({
    required this.id,
    required this.listId,
    required this.content,
    this.metadata,
    required this.isCompleted,
    required this.addedById,
    required this.createdAt,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      content: json['content'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isCompleted: json['isCompleted'] as bool,
      addedById: json['addedById'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'content': content,
      'metadata': metadata,
      'isCompleted': isCompleted,
      'addedById': addedById,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ListItem copyWith({
    String? id,
    String? listId,
    String? content,
    Map<String, dynamic>? metadata,
    bool? isCompleted,
    String? addedById,
    DateTime? createdAt,
  }) {
    return ListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      isCompleted: isCompleted ?? this.isCompleted,
      addedById: addedById ?? this.addedById,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
