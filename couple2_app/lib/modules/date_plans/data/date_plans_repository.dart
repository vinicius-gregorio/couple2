import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IDatePlansRepository {
  Future<DatePlan> create({
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
  });

  Future<DatePlanPage> list({required String scope, String? cursor});

  Future<DatePlan> get(String id);

  Future<DatePlan> update(
    String id, {
    String? title,
    DateTime? scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearSource = false,
  });

  Future<DatePlan> accept(String id);

  Future<DatePlan> decline(String id, {String? note});

  Future<DatePlan> counter(
    String id, {
    required DateTime scheduledAt,
    String? note,
  });

  Future<DatePlan> cancel(String id, {String? note});

  Future<DatePlan> done(String id);
}

class DatePlansRepository implements IDatePlansRepository {
  DatePlansRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<DatePlan> create({
    required String title,
    required DateTime scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
  }) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans',
      data: {
        'title': title.trim(),
        'scheduledAt': isoWithOffset(scheduledAt),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (sourceListItemId != null) 'sourceListItemId': sourceListItemId,
      },
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlanPage> list({required String scope, String? cursor}) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/date-plans',
      queryParameters: {'scope': scope, if (cursor != null) 'cursor': cursor},
    );
    return DatePlanPage.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> get(String id) async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/date-plans/$id',
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> update(
    String id, {
    String? title,
    DateTime? scheduledAt,
    String? location,
    String? description,
    String? sourceListItemId,
    bool clearLocation = false,
    bool clearDescription = false,
    bool clearSource = false,
  }) async {
    final response = await _httpClient.patch<Map<String, dynamic>>(
      '/date-plans/$id',
      data: {
        if (title != null) 'title': title.trim(),
        if (scheduledAt != null) 'scheduledAt': isoWithOffset(scheduledAt),
        if (clearLocation)
          'location': null
        else if (location != null)
          'location': location.trim(),
        if (clearDescription)
          'description': null
        else if (description != null)
          'description': description.trim(),
        if (clearSource)
          'sourceListItemId': null
        else if (sourceListItemId != null)
          'sourceListItemId': sourceListItemId,
      },
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> accept(String id) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans/$id/accept',
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> decline(String id, {String? note}) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans/$id/decline',
      data: {if (_note(note) != null) 'note': _note(note)},
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> counter(
    String id, {
    required DateTime scheduledAt,
    String? note,
  }) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans/$id/counter',
      data: {
        'scheduledAt': isoWithOffset(scheduledAt),
        if (_note(note) != null) 'note': _note(note),
      },
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> cancel(String id, {String? note}) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans/$id/cancel',
      data: {if (_note(note) != null) 'note': _note(note)},
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  @override
  Future<DatePlan> done(String id) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/date-plans/$id/done',
    );
    return DatePlan.fromJson(_asMap(response.data));
  }

  String? _note(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Resposta inesperada do servidor');
  }
}
