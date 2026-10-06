import 'dart:typed_data';

import 'package:couple2_app/app/session.dart';
import 'package:couple2_app/core/external/http_client/cpl_http_response.dart';
import 'package:couple2_app/core/external/http_client/exceptions/exceptions.dart';
import 'package:couple2_app/core/external/http_client/cpl_http_type_defs.dart';
import 'package:couple2_app/core/external/http_client/i_cpl_http_client.dart';
import 'package:couple2_app/modules/pairing/data/pairing_repository.dart';
import 'package:couple2_app/modules/pairing/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET /auth/me keeps the pairing code only while unpaired', () {
    final unpaired = Session.fromMe({
      'user': {
        'id': 'user-a',
        'email': 'a@example.com',
        'name': 'Ana',
        'coupleId': null,
      },
      'pairing': {
        'isPaired': false,
        'pairingCode': 'ABC123',
        'pairingCodeExpiresAt': '2026-11-06T15:00:00.000Z',
      },
      'partner': null,
    });
    expect(unpaired.pairingCode, 'ABC123');
    expect(unpaired.pairingCodeExpiresAt, isNotNull);
    expect(unpaired.isPaired, isFalse);
    expect(sessionNeedsPairing(unpaired), isTrue);

    final paired = Session.fromMe({
      'user': {
        'id': 'user-a',
        'email': 'a@example.com',
        'name': 'Ana',
        'coupleId': 'couple-1',
      },
      'pairing': {'isPaired': true},
      'partner': {
        'id': 'user-b',
        'name': 'Bruno',
        'email': 'b@example.com',
        'picture': null,
      },
    });
    expect(paired.coupleId, 'couple-1');
    expect(paired.partnerId, 'user-b');
    expect(paired.pairingCode, isNull);
    expect(sessionNeedsPairing(paired), isFalse);
  });

  test('status JSON matches the three Nest shapes', () {
    final unpaired = PairingSnapshot.fromJson({
      'status': 'unpaired',
      'pairingCode': 'ABC123',
      'pairingCodeExpiresAt': '2026-11-06T15:00:00.000Z',
    });
    expect(unpaired.phase, PairingPhase.unpaired);
    expect(unpaired.pairingCode, 'ABC123');
    expect(unpaired.pairingCodeExpiresAt, DateTime.utc(2026, 11, 6, 15));

    final pending = PairingSnapshot.fromJson({
      'status': 'pending',
      'pendingCode': 'XYZ789',
      'message': 'Waiting for your partner to enter your code',
    });
    expect(pending.phase, PairingPhase.pending);
    expect(pending.pendingCode, 'XYZ789');
    expect(pending.pairingCode, isNull);

    final paired = PairingSnapshot.fromJson({
      'status': 'paired',
      'partner': {'id': 'user-b', 'name': 'Bruno'},
    });
    expect(paired.phase, PairingPhase.paired);
    expect(paired.partner?.id, 'user-b');
    expect(paired.partner?.name, 'Bruno');
  });

  test('pair JSON is pending without a partner, or paired with one', () {
    final pending = PairResult.fromJson({
      'status': 'pending',
      'message':
          'Pairing request sent. Waiting for your partner to enter your code.',
    });
    expect(pending.phase, PairingPhase.pending);
    expect(pending.partner, isNull);

    final paired = PairResult.fromJson({
      'status': 'paired',
      'message': 'Successfully paired with your partner!',
      'partner': {'id': 'user-b', 'name': null},
    });
    expect(paired.phase, PairingPhase.paired);
    expect(paired.partner?.id, 'user-b');
    expect(paired.partner?.name, isNull);
  });

  test('pending status borrows the code from the session', () {
    const pending = PairingSnapshot(
      phase: PairingPhase.pending,
      pendingCode: 'XYZ789',
    );
    final shown = shownPairingCode(
      status: pending,
      sessionCode: 'ABC123',
      sessionExpiresAt: DateTime.utc(2026, 11, 6),
    );
    expect(shown.code, 'ABC123');
    expect(shown.expiresAt, DateTime.utc(2026, 11, 6));
  });

  test('expiry copy is local and omitted when the API has no date', () {
    expect(pairingExpiryLabel(null), isNull);
    expect(
      pairingExpiryLabel(DateTime(2026, 2, 18, 15), now: DateTime(2026, 1, 1)),
      'Válido até 18/02/2026 às 15:00',
    );
    expect(
      pairingExpiryLabel(DateTime(2020, 1, 2, 3, 4), now: DateTime(2026, 1, 1)),
      contains('expirou'),
    );
  });

  test('partner code validation blocks format and self-code', () {
    expect(normalizePairingCode(' xyz789 '), 'XYZ789');
    expect(
      validatePartnerCode('ab'),
      'O código precisa ter 6 letras ou números.',
    );
    expect(
      validatePartnerCode('abc123', myCode: 'ABC123'),
      'Você não pode usar o seu próprio código.',
    );
    expect(validatePartnerCode('xyz789', myCode: 'ABC123'), isNull);
  });

  test('Nest errors become PT-BR', () {
    expect(
      pairingErrorMessage(
        CPLHttpBadRequestException(
          response: CPLHttpResponse(
            data: {'message': 'This pairing code has expired'},
            statusCode: 400,
            statusMessage: 'Bad Request',
            headers: null,
          ),
        ),
      ),
      'Esse código expirou. Peça um código novo.',
    );
    expect(
      pairingErrorMessage(
        CPLHttpBadRequestException(
          response: CPLHttpResponse(
            data: {'message': 'You cannot pair with yourself'},
            statusCode: 400,
            statusMessage: 'Bad Request',
            headers: null,
          ),
        ),
      ),
      'Você não pode usar o seu próprio código.',
    );
    expect(
      pairingErrorMessage(
        CPLHttpBadRequestException(
          response: CPLHttpResponse(
            data: {
              'message': [
                'code must match /^[A-Za-z0-9]{6}\$/ regular expression',
              ],
            },
            statusCode: 400,
            statusMessage: 'Bad Request',
            headers: null,
          ),
        ),
      ),
      'O código precisa ter 6 letras ou números.',
    );
    expect(
      pairingErrorMessage(
        CPLHttpNotFoundException(
          response: CPLHttpResponse(
            data: {
              'message': 'Invalid pairing code. No user found with this code.',
            },
            statusCode: 404,
            statusMessage: 'Not Found',
            headers: null,
          ),
        ),
      ),
      'Não encontramos ninguém com esse código.',
    );
    expect(
      pairingErrorMessage(
        CPLHttpConflictException(
          response: CPLHttpResponse(
            data: {'message': 'You are already paired with a partner'},
            statusCode: 409,
            statusMessage: 'Conflict',
            headers: null,
          ),
        ),
      ),
      'Você já está pareado.',
    );
    expect(
      pairingErrorMessage(
        CPLHttpConflictException(
          response: CPLHttpResponse(
            data: {'message': 'This user is already paired with someone else'},
            statusCode: 409,
            statusMessage: 'Conflict',
            headers: null,
          ),
        ),
      ),
      'Essa pessoa já está pareada com outra.',
    );
    expect(
      pairingErrorMessage(const CPLHttpNoInternetConnectionException()),
      'Sem conexão. Verifique a internet e tente de novo.',
    );
    expect(
      pairingErrorMessage(const CPLHttpDeadlineExceededException()),
      'A conexão demorou demais. Tente de novo.',
    );
    expect(
      pairingErrorMessage(Exception('nope'), action: PairingAction.cancel),
      'Não foi possível cancelar o pedido. Tente de novo.',
    );
    expect(
      pairingErrorMessage(Exception('nope'), action: PairingAction.unpair),
      'Não foi possível desfazer o par. Tente de novo.',
    );
  });

  test('repository calls the Nest pairing paths and body', () async {
    final http = _RecordingHttp();
    final repo = PairingRepository(httpClient: http);

    http.data = {
      'status': 'unpaired',
      'pairingCode': 'ABC123',
      'pairingCodeExpiresAt': '2026-11-06T15:00:00.000Z',
    };
    final status = await repo.getStatus();
    expect(status.pairingCode, 'ABC123');

    http.data = {
      'status': 'pending',
      'message':
          'Pairing request sent. Waiting for your partner to enter your code.',
    };
    final pending = await repo.pair('xyz789');
    expect(pending.phase, PairingPhase.pending);

    http.data = {'message': 'Pairing request cancelled'};
    await repo.cancelRequest();

    http.data = {'message': 'Successfully unpaired'};
    await repo.unpair();

    expect(http.calls.map((call) => (call.$1, call.$2)).toList(), [
      ('GET', '/pairing/status'),
      ('POST', '/pairing/pair'),
      ('DELETE', '/pairing/request'),
      ('DELETE', '/pairing/unpair'),
    ]);
    expect(http.calls[1].$3, {'code': 'XYZ789'});
  });
}

class _RecordingHttp implements ICPLHttpClient {
  _RecordingHttp()
    : baseUrl = 'https://example.test',
      receiveTimeout = null,
      connectTimeout = null,
      sendTimeout = null,
      contentType = null;

  Object? data;
  final calls = <(String, String, Object?)>[];

  @override
  String baseUrl;

  @override
  Duration? receiveTimeout;

  @override
  Duration? connectTimeout;

  @override
  Duration? sendTimeout;

  @override
  String? contentType;

  @override
  void setBaseUrl(String url) => baseUrl = url;

  @override
  Future<bool> isInternetAvailable() async => true;

  CPLHttpResponse<T> _response<T>() {
    return CPLHttpResponse<T>(
      data: data as T?,
      statusCode: 200,
      statusMessage: 'OK',
      headers: null,
    );
  }

  @override
  Future<CPLHttpResponse<T>> get<T>(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(('GET', path, null));
    return _response<T>();
  }

  @override
  Future<CPLHttpResponse<T>> post<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(('POST', path, data));
    return _response<T>();
  }

  @override
  Future<CPLHttpResponse<T>> delete<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    calls.add(('DELETE', path, data));
    return _response<T>();
  }

  @override
  Future<CPLHttpResponse<T>> patch<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<CPLHttpResponse<T>> put<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();

  @override
  Future<CPLHttpResponse<Uint8List>> getBytes(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) => throw UnimplementedError();
}
