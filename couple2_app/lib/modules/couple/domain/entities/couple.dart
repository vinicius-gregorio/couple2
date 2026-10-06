class CouplePartner {
  const CouplePartner({
    required this.id,
    this.name,
    this.picture,
    this.birthDate,
  });

  final String id;
  final String? name;
  final String? picture;
  final String? birthDate;

  factory CouplePartner.fromJson(Map<String, dynamic> json) {
    return CouplePartner(
      id: json['id'] as String,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      birthDate: json['birthDate'] as String?,
    );
  }
}

class UpcomingDate {
  const UpcomingDate({
    required this.kind,
    required this.title,
    required this.date,
    required this.inDays,
    this.coupleDateId,
    this.self = false,
  });

  final String kind;
  final String title;
  final String date;
  final int inDays;
  final String? coupleDateId;

  /// True when this birthday belongs to the signed-in user.
  final bool self;

  factory UpcomingDate.fromJson(Map<String, dynamic> json) {
    return UpcomingDate(
      kind: json['kind'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      inDays: json['inDays'] as int,
      coupleDateId: json['coupleDateId'] as String?,
      self: json['self'] as bool? ?? false,
    );
  }
}

class Couple {
  const Couple({
    required this.id,
    required this.pairedAt,
    required this.timezone,
    required this.daysTogether,
    required this.partner,
    required this.upcoming,
    this.anniversaryDate,
  });

  final String id;
  final DateTime pairedAt;
  final String? anniversaryDate;
  final String timezone;
  final int daysTogether;
  final CouplePartner partner;
  final List<UpcomingDate> upcoming;

  factory Couple.fromJson(Map<String, dynamic> json) {
    return Couple(
      id: json['id'] as String,
      pairedAt: DateTime.parse(json['pairedAt'] as String),
      anniversaryDate: json['anniversaryDate'] as String?,
      timezone: json['timezone'] as String,
      daysTogether: json['daysTogether'] as int,
      partner: CouplePartner.fromJson(json['partner'] as Map<String, dynamic>),
      upcoming: (json['upcoming'] as List<dynamic>)
          .map((entry) => UpcomingDate.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}
