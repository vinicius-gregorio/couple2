class User {
  final String id;
  final String email;
  final String name;
  final String? picture;
  final String? partnerId;
  final String pairingCode;
  final DateTime pairingCodeExpiresAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.picture,
    this.partnerId,
    required this.pairingCode,
    required this.pairingCodeExpiresAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      picture: json['picture'] as String?,
      partnerId: json['partnerId'] as String?,
      pairingCode: json['pairingCode'] as String,
      pairingCodeExpiresAt: DateTime.parse(
        json['pairingCodeExpiresAt'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'picture': picture,
      'partnerId': partnerId,
      'pairingCode': pairingCode,
      'pairingCodeExpiresAt': pairingCodeExpiresAt.toIso8601String(),
    };
  }
}
