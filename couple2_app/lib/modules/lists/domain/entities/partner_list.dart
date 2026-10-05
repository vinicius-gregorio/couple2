import 'list_item.dart';

class PartnerList {
  final String id;
  final String type;
  final String name;
  final String ownerId;
  final List<ListItem> items;
  final DateTime createdAt;

  const PartnerList({
    required this.id,
    required this.type,
    required this.name,
    required this.ownerId,
    required this.items,
    required this.createdAt,
  });

  factory PartnerList.fromJson(Map<String, dynamic> json) {
    return PartnerList(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => ListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'ownerId': ownerId,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PartnerList copyWith({
    String? id,
    String? type,
    String? name,
    String? ownerId,
    List<ListItem>? items,
    DateTime? createdAt,
  }) {
    return PartnerList(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
