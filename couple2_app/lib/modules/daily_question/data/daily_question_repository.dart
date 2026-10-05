import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IDailyQuestionRepository {
  Future<CoupleQuestion> getToday();

  Future<CoupleQuestion> answer(String coupleQuestionId, String text);

  Future<QuestionHistoryPageResult> history({String? cursor, int limit = 20});
}

class DailyQuestionRepository implements IDailyQuestionRepository {
  DailyQuestionRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<CoupleQuestion> getToday() async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/questions/today',
    );
    return CoupleQuestion.fromJson(_asMap(response.data));
  }

  @override
  Future<CoupleQuestion> answer(String coupleQuestionId, String text) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/questions/$coupleQuestionId/answer',
      data: {'text': text},
    );
    return CoupleQuestion.fromJson(_asMap(response.data));
  }

  @override
  Future<QuestionHistoryPageResult> history({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/questions/history',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Resposta inesperada do servidor');
    }
    return QuestionHistoryPageResult.fromJson(data);
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Resposta inesperada do servidor');
  }
}
