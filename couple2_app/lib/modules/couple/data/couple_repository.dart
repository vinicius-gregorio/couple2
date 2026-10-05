import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class ICoupleRepository {
  Future<Couple> getCouple();
  Future<Couple> updateCouple({String? anniversaryDate, String? timezone});
  Future<List<CoupleDate>> getDates();
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  });
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  });
  Future<void> deleteDate(String id);
  Future<void> updateMyBirthDate(String? birthDate);
}

class CoupleRepository implements ICoupleRepository {
  CoupleRepository({required ICPLHttpClient httpClient})
      : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<Couple> getCouple() async {
    final response = await _httpClient.get<Map<String, dynamic>>('/couple');
    return Couple.fromJson(_asMap(response.data));
  }

  @override
  Future<Couple> updateCouple({
    String? anniversaryDate,
    String? timezone,
  }) async {
    final response = await _httpClient.patch<Map<String, dynamic>>(
      '/couple',
      data: {
        if (anniversaryDate != null) 'anniversaryDate': anniversaryDate,
        if (timezone != null) 'timezone': timezone,
      },
    );
    return Couple.fromJson(_asMap(response.data));
  }

  @override
  Future<List<CoupleDate>> getDates() async {
    final response = await _httpClient.get<List<dynamic>>('/couple/dates');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .map((entry) => CoupleDate.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CoupleDate> createDate({
    required String title,
    required String date,
    String? recurrence,
  }) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/couple/dates',
      data: {
        'title': title,
        'date': date,
        if (recurrence != null) 'recurrence': recurrence,
      },
    );
    return CoupleDate.fromJson(_asMap(response.data));
  }

  @override
  Future<CoupleDate> updateDate(
    String id, {
    String? title,
    String? date,
    String? recurrence,
  }) async {
    final response = await _httpClient.patch<Map<String, dynamic>>(
      '/couple/dates/$id',
      data: {
        if (title != null) 'title': title,
        if (date != null) 'date': date,
        if (recurrence != null) 'recurrence': recurrence,
      },
    );
    return CoupleDate.fromJson(_asMap(response.data));
  }

  @override
  Future<void> deleteDate(String id) async {
    await _httpClient.delete<void>('/couple/dates/$id');
  }

  @override
  Future<void> updateMyBirthDate(String? birthDate) async {
    await _httpClient.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'birthDate': birthDate},
    );
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw Exception('Resposta inesperada do servidor');
  }
}
