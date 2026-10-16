class Session {
  const Session({
    required this.id,
    required this.email,
    required this.name,
    required this.isPaired,
    this.picture,
    this.coupleId,
    this.birthDate,
    this.partnerId,
    this.partnerName,
    this.partnerPicture,
    this.pairingCode,
    this.pairingCodeExpiresAt,
  });

  final String id;
  final String email;
  final String name;
  final String? picture;
  final String? coupleId;
  final String? birthDate;
  final bool isPaired;
  final String? partnerId;
  final String? partnerName;
  final String? partnerPicture;

  /// Present on `GET /auth/me` only while the user is unpaired.
  final String? pairingCode;
  final DateTime? pairingCodeExpiresAt;

  Map<String, Object?> toCacheJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'picture': picture,
      'coupleId': coupleId,
      'birthDate': birthDate,
      'isPaired': isPaired,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerPicture': partnerPicture,
      'pairingCode': pairingCode,
      'pairingCodeExpiresAt': pairingCodeExpiresAt?.toIso8601String(),
    };
  }

  factory Session.fromCache(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || email is! String) {
      throw const FormatException('Sessão em cache inválida');
    }
    return Session(
      id: id,
      email: email,
      name: json['name'] as String? ?? '',
      picture: json['picture'] as String?,
      coupleId: json['coupleId'] as String?,
      birthDate: json['birthDate'] as String?,
      isPaired: json['isPaired'] as bool? ?? false,
      partnerId: json['partnerId'] as String?,
      partnerName: json['partnerName'] as String?,
      partnerPicture: json['partnerPicture'] as String?,
      pairingCode: json['pairingCode'] as String?,
      pairingCodeExpiresAt: _date(json['pairingCodeExpiresAt']),
    );
  }

  factory Session.fromMe(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final pairing = json['pairing'] as Map<String, dynamic>? ?? const {};
    final partner = json['partner'] as Map<String, dynamic>?;

    return Session(
      id: user['id'] as String,
      email: user['email'] as String,
      name: (user['name'] as String?) ?? '',
      picture: user['picture'] as String?,
      coupleId: user['coupleId'] as String?,
      birthDate: user['birthDate'] as String?,
      isPaired: pairing['isPaired'] as bool? ?? partner != null,
      partnerId: partner?['id'] as String?,
      partnerName: partner?['name'] as String?,
      partnerPicture: partner?['picture'] as String?,
      pairingCode: pairing['pairingCode'] as String?,
      pairingCodeExpiresAt: _date(pairing['pairingCodeExpiresAt']),
    );
  }
}

/// Logged-in account with neither `coupleId` nor `partnerId`.
bool sessionNeedsPairing(Session? session) {
  if (session == null) return false;
  return session.coupleId == null && session.partnerId == null;
}

DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
