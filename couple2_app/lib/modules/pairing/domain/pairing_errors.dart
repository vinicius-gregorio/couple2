import '../../../core/external/http_client/exceptions/exceptions.dart';

enum PairingAction { pair, cancel, unpair, status }

/// Maps Nest pairing errors to PT-BR. The server messages stay in English.
String pairingErrorMessage(
  Object error, {
  PairingAction action = PairingAction.pair,
}) {
  if (error is CPLHttpNoInternetConnectionException) {
    return 'Sem conexão. Verifique a internet e tente de novo.';
  }
  if (error is CPLHttpDeadlineExceededException) {
    return 'A conexão demorou demais. Tente de novo.';
  }
  if (error is CPLHttpUnauthorizedException) {
    return 'Sua sessão expirou. Entre de novo.';
  }

  final server = _serverMessage(error).toLowerCase();
  if (_isNetworkText(server) ||
      _isNetworkText(error.toString().toLowerCase())) {
    return 'Sem conexão. Verifique a internet e tente de novo.';
  }

  if (server.contains('cannot pair with yourself') ||
      server.contains('pair with yourself')) {
    return 'Você não pode usar o seu próprio código.';
  }
  if (server.contains('expired')) {
    return 'Esse código expirou. Peça um código novo.';
  }
  if (server.contains('invalid code format') ||
      server.contains('alphanumeric') ||
      server.contains('must match')) {
    return 'O código precisa ter 6 letras ou números.';
  }
  if (server.contains('no user found') ||
      server.contains('invalid pairing code')) {
    return 'Não encontramos ninguém com esse código.';
  }
  if (server.contains('already paired with a partner') ||
      server.contains('you are already paired')) {
    return 'Você já está pareado.';
  }
  if (server.contains('already paired with someone')) {
    return 'Essa pessoa já está pareada com outra.';
  }
  if (server.contains('not paired') ||
      server.contains('requires you to be paired')) {
    return 'Você não está pareado.';
  }
  if (server.contains('user not found')) {
    return 'Não encontrei sua conta. Entre de novo.';
  }

  if (error is CPLHttpNotFoundException) {
    return 'Não encontramos ninguém com esse código.';
  }
  if (error is CPLHttpConflictException) {
    return 'Não dá para parear agora. Alguém já está pareado.';
  }
  if (error is CPLHttpForbiddenException) {
    return 'Você não está pareado.';
  }

  final statusCode = error is CPLHttpException
      ? error.response?.statusCode
      : null;
  if (statusCode != null && statusCode >= 500) {
    return 'O servidor não respondeu. Tente de novo.';
  }

  switch (action) {
    case PairingAction.cancel:
      return 'Não foi possível cancelar o pedido. Tente de novo.';
    case PairingAction.unpair:
      return 'Não foi possível desfazer o par. Tente de novo.';
    case PairingAction.status:
      return 'Não foi possível atualizar o pareamento. Tente de novo.';
    case PairingAction.pair:
      return 'Não foi possível parear agora. Tente de novo.';
  }
}

String _serverMessage(Object error) {
  if (error is! CPLHttpException) return '';
  final data = error.response?.data;
  if (data is! Map) return '';
  final message = data['message'];
  if (message is String) return message;
  if (message is List) {
    return message.whereType<String>().join(' ');
  }
  return '';
}

bool _isNetworkText(String raw) {
  return raw.contains('failed host lookup') ||
      raw.contains('socketexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection abort') ||
      raw.contains('connection refused') ||
      raw.contains('error connecting');
}
