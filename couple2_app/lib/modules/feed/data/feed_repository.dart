import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IFeedRepository {
  Future<FeedPageResult> getFeed({String? cursor, int limit = 20});

  Future<int> unreadCount();

  Future<void> markSeen();
}

class FeedRepository implements IFeedRepository {
  FeedRepository({required ICPLHttpClient httpClient}) : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<FeedPageResult> getFeed({String? cursor, int limit = 20}) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/feed',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Resposta inesperada do servidor');
    }
    return FeedPageResult.fromJson(data);
  }

  @override
  Future<int> unreadCount() async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/feed/unread-count',
    );
    final count = response.data?['count'];
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<void> markSeen() async {
    await _httpClient.post<Map<String, dynamic>>('/feed/seen');
  }
}
