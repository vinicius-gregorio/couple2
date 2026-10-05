import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class INotificationsRepository {
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  });

  Future<void> deleteDevice(String token);

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> patch,
  );
}

class NotificationsRepository implements INotificationsRepository {
  NotificationsRepository({required ICPLHttpClient httpClient})
      : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? appVersion,
    String? locale,
  }) async {
    await _httpClient.post<Map<String, dynamic>>(
      '/devices',
      data: {
        'token': token,
        'platform': platform,
        if (appVersion != null) 'appVersion': appVersion,
        if (locale != null) 'locale': locale,
      },
    );
  }

  @override
  Future<void> deleteDevice(String token) async {
    await _httpClient.delete<void>('/devices/${Uri.encodeComponent(token)}');
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/notifications/preferences',
    );
    return NotificationPreferences.fromJson(_asMap(response.data));
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> patch,
  ) async {
    final response = await _httpClient.patch<Map<String, dynamic>>(
      '/notifications/preferences',
      data: patch,
    );
    return NotificationPreferences.fromJson(_asMap(response.data));
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Resposta inesperada do servidor');
  }
}
