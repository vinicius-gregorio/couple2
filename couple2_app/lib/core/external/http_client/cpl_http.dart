import 'clients/dio/dio_client.dart';
import 'i_cpl_http_client.dart';
import 'cpl_http_interceptor.dart';

class CPLHttpClient {
  CPLHttpClient._();

  /// Creates an instance of [ICPLHttpClient] with the specified configuration.
  ///
  /// The [baseUrl] parameter is required and specifies the base URL for the HTTP client.
  /// Optional parameters include:
  /// - [receiveTimeout]: The duration for receiving data.
  /// - [connectTimeout]: The duration for establishing a connection.
  /// - [sendTimeout]: The duration for sending data.
  /// - [contentType]: The content type for the HTTP client.
  ///
  /// Returns an instance of [DioClient] configured with the provided parameters.
  static ICPLHttpClient create({
    required String baseUrl,
    Duration? receiveTimeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    String? contentType,
    List<CPLHttpInterceptor>? interceptors,
  }) {
    return DioClient(
      baseUrl: baseUrl,
      receiveTimeout: receiveTimeout,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      contentType: contentType,
      interceptors: interceptors,
    );
  }
}
