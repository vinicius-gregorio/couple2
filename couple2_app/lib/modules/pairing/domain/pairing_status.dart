enum PairingPhase { unpaired, pending, paired }

class PairingPartner {
  const PairingPartner({required this.id, this.name});

  final String id;
  final String? name;

  static PairingPartner? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = raw['name'];
    return PairingPartner(id: id, name: name is String ? name : null);
  }
}

/// `GET /pairing/status` and the fields we keep after `POST /pairing/pair`.
class PairingSnapshot {
  const PairingSnapshot({
    required this.phase,
    this.message,
    this.pairingCode,
    this.pairingCodeExpiresAt,
    this.pendingCode,
    this.partner,
  });

  final PairingPhase phase;
  final String? message;
  final String? pairingCode;
  final DateTime? pairingCodeExpiresAt;
  final String? pendingCode;
  final PairingPartner? partner;

  factory PairingSnapshot.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status is! String) {
      throw const FormatException('Resposta de pareamento sem status');
    }
    switch (status) {
      case 'unpaired':
        return PairingSnapshot(
          phase: PairingPhase.unpaired,
          message: _string(json['message']),
          pairingCode: _string(json['pairingCode']),
          pairingCodeExpiresAt: _date(json['pairingCodeExpiresAt']),
        );
      case 'pending':
        return PairingSnapshot(
          phase: PairingPhase.pending,
          message: _string(json['message']),
          pendingCode: _string(json['pendingCode']),
        );
      case 'paired':
        return PairingSnapshot(
          phase: PairingPhase.paired,
          message: _string(json['message']),
          partner: PairingPartner.fromJson(json['partner']),
        );
      default:
        throw FormatException('Status de pareamento desconhecido: $status');
    }
  }
}

/// `POST /pairing/pair` response. Status is `pending` or `paired`.
class PairResult {
  const PairResult({required this.phase, required this.message, this.partner});

  final PairingPhase phase;
  final String message;
  final PairingPartner? partner;

  factory PairResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status != 'pending' && status != 'paired') {
      throw FormatException('Resposta de pareamento inesperada: $status');
    }
    final message = json['message'];
    return PairResult(
      phase: status == 'paired' ? PairingPhase.paired : PairingPhase.pending,
      message: message is String ? message : '',
      partner: PairingPartner.fromJson(json['partner']),
    );
  }
}

/// Code to show the user. Pending status does not include `pairingCode`;
/// that value stays on `GET /auth/me`.
class ShownPairingCode {
  const ShownPairingCode({this.code, this.expiresAt});

  final String? code;
  final DateTime? expiresAt;
}

ShownPairingCode shownPairingCode({
  PairingSnapshot? status,
  String? sessionCode,
  DateTime? sessionExpiresAt,
}) {
  if (status?.phase == PairingPhase.unpaired) {
    final code = status?.pairingCode;
    if (code != null && code.isNotEmpty) {
      return ShownPairingCode(
        code: code,
        expiresAt: status?.pairingCodeExpiresAt,
      );
    }
  }
  if (sessionCode != null && sessionCode.isNotEmpty) {
    return ShownPairingCode(code: sessionCode, expiresAt: sessionExpiresAt);
  }
  final fallback = status?.pairingCode;
  if (fallback != null && fallback.isNotEmpty) {
    return ShownPairingCode(
      code: fallback,
      expiresAt: status?.pairingCodeExpiresAt,
    );
  }
  return const ShownPairingCode();
}

String? _string(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
