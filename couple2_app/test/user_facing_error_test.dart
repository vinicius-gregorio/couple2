import 'dart:async';

import 'package:couple2_app/core/errors/user_facing_error.dart';
import 'package:couple2_app/core/external/http_client/exceptions/exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('dio offline and timeouts stay in portuguese', () {
    final offline = userFacingError(
      const CPLHttpNoInternetConnectionException(
        message: 'Error connecting to the server',
      ),
    );
    expect(offline, offlineUserMessage);
    expect(offline.toLowerCase(), isNot(contains('error connecting')));
    expect(offline, isNot(contains('CPLHttp')));

    final wrapped = userFacingError(
      const CPLHttpException(message: 'Error connecting to the server'),
    );
    expect(wrapped, offlineUserMessage);
    expect(
      userFacingError(
        const CPLHttpException(
          message:
              'The connection errored: The XMLHttpRequest onError callback was called.',
        ),
      ),
      offlineUserMessage,
    );
    expect(
      userFacingError(
        Exception("Couldn't save right now"),
      ),
      isNot(contains('Couldn')),
    );
    expect(wrapped, isNot(contains('Source stack')));

    expect(
      userFacingError(TimeoutException('Future not completed')),
      slowConnectionMessage,
    );
    expect(
      userFacingError(const CPLHttpDeadlineExceededException()),
      slowConnectionMessage,
    );
    expect(slowConnectionMessage, isNot(contains('Future')));
  });

  test('firebase failures use the same mapper', () {
    expect(
      userFacingError(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error (such as timeout) has occurred.',
        ),
      ),
      offlineUserMessage,
    );
    expect(
      userFacingError(
        FirebaseAuthException(
          code: 'popup-closed-by-user',
          message: 'The popup has been closed by the user before finalizing.',
        ),
      ),
      'Entrada cancelada',
    );
    expect(
      userFacingError(
        FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'The identity provider configuration is not found.',
        ),
      ),
      'Este tipo de login não está disponível.',
    );

    final unknown = userFacingError(
      FirebaseAuthException(
        code: 'popup-blocked',
        message: 'Popup blocked by the browser',
      ),
    );
    expect(unknown, fallbackUserMessage);
    expect(unknown, isNot(contains('Popup')));
    expect(unknown, isNot(contains('popup-blocked')));
  });

  test('http statuses and unknown routes never echo english', () {
    expect(
      userFacingError(const CPLHttpUnauthorizedException()),
      'Sua sessão expirou. Entre de novo.',
    );
    expect(
      userFacingError(
        const CPLHttpNotFoundException(message: 'Date not found'),
      ),
      'Não encontrei o que você pediu.',
    );
    expect(
      userFacingError(
        const CPLHttpForbiddenException(message: 'Forbidden'),
      ),
      'Você não pode fazer isso agora.',
    );
    expect(
      userFacingError(
        const CPLHttpBadRequestException(message: 'title must be shorter'),
      ),
      'Não deu para salvar. Confira os dados.',
    );
    expect(
      userFacingError(
        const CPLHttpInternalServerErrorException(
          message: 'Internal Server Error',
        ),
      ),
      'O servidor não respondeu. Tente de novo.',
    );
    final route = userFacingError(
      GoException('no routes for location: /missing'),
    );
    expect(route, 'Essa página não existe.');
    expect(route, isNot(contains('GoException')));
    expect(route, isNot(contains('no routes')));
  });

  test('toString and generic english never reach the user', () {
    final error = CPLHttpException(
      message: 'Error connecting to the server',
      stackTrace: StackTrace.current,
    );
    final message = userFacingError(error);
    expect(message, offlineUserMessage);
    expect(message, isNot(contains('CPLHttpException')));
    expect(message, isNot(error.toString()));

    final generic = userFacingError(Exception('Something went wrong'));
    expect(generic, fallbackUserMessage);
    expect(generic, isNot(contains('Something')));

    expect(
      userFacingError(Exception('SocketException: Connection refused')),
      offlineUserMessage,
    );
    expect(
      userFacingError(
        Exception('nope'),
        fallback: 'Não foi possível carregar o feed.',
      ),
      'Não foi possível carregar o feed.',
    );
  });
}
