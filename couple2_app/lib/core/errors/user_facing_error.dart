import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../external/http_client/exceptions/exceptions.dart';

/// Shown when an API or Firebase failure has no more specific Portuguese copy.
const fallbackUserMessage = 'Não foi possível concluir. Tente de novo.';

const offlineUserMessage = 'Sem conexão. Verifique a internet e tente de novo.';

const slowConnectionMessage = 'A conexão demorou demais. Tente de novo.';

/// One mapper for Dio, Firebase, routing, and unknown failures.
///
/// Never returns [Object.toString], a stack trace, or the server's English text.
String userFacingError(Object error, {String? fallback}) {
  final generic = fallback ?? fallbackUserMessage;

  if (error is FirebaseAuthException) {
    switch (error.code.trim()) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Entrada cancelada';
      case 'network-request-failed':
        return offlineUserMessage;
      case 'operation-not-allowed':
        return 'Este tipo de login não está disponível.';
      default:
        return generic;
    }
  }

  if (error is TimeoutException || error is CPLHttpDeadlineExceededException) {
    return slowConnectionMessage;
  }
  if (error is CPLHttpNoInternetConnectionException) {
    return offlineUserMessage;
  }
  if (error is GoException) {
    return 'Essa página não existe.';
  }

  if (_looksOffline(_blob(error))) return offlineUserMessage;

  if (error is CPLHttpUnauthorizedException) {
    return 'Sua sessão expirou. Entre de novo.';
  }
  if (error is CPLHttpForbiddenException) {
    return 'Você não pode fazer isso agora.';
  }
  if (error is CPLHttpNotFoundException) {
    return 'Não encontrei o que você pediu.';
  }
  if (error is CPLHttpConflictException) {
    return 'Isso mudou. Atualize e tente de novo.';
  }
  if (error is CPLHttpBadRequestException ||
      error is CPLHttpUnprocessableEntityException) {
    return 'Não deu para salvar. Confira os dados.';
  }
  if (error is CPLHttpInternalServerErrorException) {
    return 'O servidor não respondeu. Tente de novo.';
  }
  if (error is CPLHttpException) {
    final status = error.response?.statusCode;
    if (status != null && status >= 500) {
      return 'O servidor não respondeu. Tente de novo.';
    }
    return generic;
  }

  return generic;
}

String _blob(Object error) {
  final parts = <String>[error.runtimeType.toString(), error.toString()];
  if (error is CPLHttpException) {
    final message = error.message;
    if (message != null) parts.add(message);
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      parts.add(data['message'].toString());
    }
  }
  return parts.join(' ').toLowerCase();
}

bool _looksOffline(String raw) {
  return raw.contains('failed host lookup') ||
      raw.contains('socketexception') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection abort') ||
      raw.contains('connection refused') ||
      raw.contains('error connecting') ||
      raw.contains('network-request-failed') ||
      raw.contains('xmlhttprequest error') ||
      raw.contains('clientexception');
}
