final _pairingCodePattern = RegExp(r'^[A-Z0-9]{6}$');

/// Same normalization as `PairingService.requestPairing`: trim + uppercase.
String normalizePairingCode(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

bool isValidPairingCode(String normalized) {
  return _pairingCodePattern.hasMatch(normalized);
}

/// Client-side check before `POST /pairing/pair`. Null means the code can be sent.
String? validatePartnerCode(String raw, {String? myCode}) {
  final code = normalizePairingCode(raw);
  if (!isValidPairingCode(code)) {
    return 'O código precisa ter 6 letras ou números.';
  }
  final mine = myCode == null ? '' : normalizePairingCode(myCode);
  if (mine.isNotEmpty && code == mine) {
    return 'Você não pode usar o seu próprio código.';
  }
  return null;
}

String formatPairingExpiry(DateTime expiresAt) {
  final local = expiresAt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} às $hour:$minute';
}

/// Null when the API did not send an expiry.
String? pairingExpiryLabel(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;
  final formatted = formatPairingExpiry(expiresAt);
  final clock = now ?? DateTime.now();
  if (!expiresAt.isAfter(clock)) {
    return 'Este código expirou em $formatted. Saia e entre de novo para gerar outro.';
  }
  return 'Válido até $formatted';
}

String pairingShareText(String code) {
  return 'Meu código no Couple2 é $code. Abra o app e digite esse código. Depois eu digito o seu para a gente se conectar.';
}
