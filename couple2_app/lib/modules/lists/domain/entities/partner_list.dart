import 'list_item.dart';

class PartnerList {
  final String id;
  final String type;
  final String name;
  final String ownerId;
  final String visibility;
  final List<ListItem> items;
  final DateTime createdAt;

  /// False when the payload left `items` out. An empty list with this true
  /// means the server says the list has no rows.
  final bool itemsIncluded;

  const PartnerList({
    required this.id,
    required this.type,
    required this.name,
    required this.ownerId,
    this.visibility = 'SHARED',
    required this.items,
    required this.createdAt,
    this.itemsIncluded = true,
  });

  factory PartnerList.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final included = raw is List;
    return PartnerList(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      visibility: json['visibility'] as String? ?? 'SHARED',
      items: included
          ? raw
                .map((e) => ListItem.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      itemsIncluded: included,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'ownerId': ownerId,
      'visibility': visibility,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PartnerList copyWith({
    String? id,
    String? type,
    String? name,
    String? ownerId,
    String? visibility,
    List<ListItem>? items,
    DateTime? createdAt,
    bool? itemsIncluded,
  }) {
    return PartnerList(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      itemsIncluded: itemsIncluded ?? this.itemsIncluded,
    );
  }
}

/// Keeps local rows only when [fresh] did not include an items array.
List<PartnerList> preserveLocalItems(
  List<PartnerList> local,
  List<PartnerList> fresh,
) {
  final byId = {for (final list in local) list.id: list};
  return [
    for (final next in fresh)
      if (!next.itemsIncluded && (byId[next.id]?.items.isNotEmpty ?? false))
        next.copyWith(items: byId[next.id]!.items, itemsIncluded: true)
      else
        next,
  ];
}
