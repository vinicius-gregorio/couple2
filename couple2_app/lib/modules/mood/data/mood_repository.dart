import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IMoodRepository {
  Future<MoodCheckin> create({required MoodLevel mood, String? note});

  Future<MoodCurrent> current();

  Future<MoodHistory> history({int days = 30});
}

class MoodRepository implements IMoodRepository {
  MoodRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<MoodCheckin> create({required MoodLevel mood, String? note}) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/mood',
      data: {
        'mood': mood.apiValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return MoodCheckin.fromJson(_asMap(response.data));
  }

  @override
  Future<MoodCurrent> current() async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/mood/current',
    );
    return MoodCurrent.fromJson(_asMap(response.data));
  }

  @override
  Future<MoodHistory> history({int days = 30}) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/mood/history',
      queryParameters: {'days': days},
    );
    return MoodHistory.fromJson(_asMap(response.data));
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Resposta inesperada do servidor');
  }
}
