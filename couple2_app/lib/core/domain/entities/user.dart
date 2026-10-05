class User {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;
  final String? partnerId;
  final String? pairingCode;
  final DateTime? pairingCodeExpiresAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.partnerId,
    this.pairingCode,
    this.pairingCodeExpiresAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      profilePictureUrl: json['picture'] as String?,
      partnerId: json['partnerId'] as String?,
      pairingCode: json['pairingCode'] as String?,
      pairingCodeExpiresAt: json['pairingCodeExpiresAt'] != null
          ? DateTime.parse(json['pairingCodeExpiresAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'picture': profilePictureUrl,
      'partnerId': partnerId,
      'pairingCode': pairingCode,
      'pairingCodeExpiresAt': pairingCodeExpiresAt?.toIso8601String(),
    };
  }
}
