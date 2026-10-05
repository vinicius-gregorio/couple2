import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class INudgesRepository {
  Future<Nudge> send({required NudgeKind kind, String? message});

  Future<NudgePage> received({String? cursor});

  Future<Nudge> markSeen(String id);
}

class NudgesRepository implements INudgesRepository {
  NudgesRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<Nudge> send({required NudgeKind kind, String? message}) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/nudges',
      data: {
        'kind': kind.apiValue,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return Nudge.fromJson(_asMap(response.data));
  }

  @override
  Future<NudgePage> received({String? cursor}) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/nudges/received',
      queryParameters: {if (cursor != null) 'cursor': cursor},
    );
    return NudgePage.fromJson(_asMap(response.data));
  }

  @override
  Future<Nudge> markSeen(String id) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/nudges/$id/seen',
    );
    return Nudge.fromJson(_asMap(response.data));
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Resposta inesperada do servidor');
  }
}
