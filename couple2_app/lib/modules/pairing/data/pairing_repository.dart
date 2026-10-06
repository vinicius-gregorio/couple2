import '../../../core/core.dart';
import '../domain/domain.dart';

abstract class IPairingRepository {
  Future<PairingSnapshot> getStatus();
  Future<PairResult> pair(String code);
  Future<void> cancelRequest();
  Future<void> unpair();
}

class PairingRepository implements IPairingRepository {
  PairingRepository({required ICPLHttpClient httpClient})
    : _httpClient = httpClient;

  final ICPLHttpClient _httpClient;

  @override
  Future<PairingSnapshot> getStatus() async {
    final response = await _httpClient.get<Map<String, dynamic>>(
      '/pairing/status',
    );
    return PairingSnapshot.fromJson(_asMap(response.data));
  }

  @override
  Future<PairResult> pair(String code) async {
    final response = await _httpClient.post<Map<String, dynamic>>(
      '/pairing/pair',
      data: {'code': normalizePairingCode(code)},
    );
    return PairResult.fromJson(_asMap(response.data));
  }

  @override
  Future<void> cancelRequest() async {
    await _httpClient.delete<Map<String, dynamic>>('/pairing/request');
  }

  @override
  Future<void> unpair() async {
    await _httpClient.delete<Map<String, dynamic>>('/pairing/unpair');
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Resposta inesperada do servidor');
  }
}
