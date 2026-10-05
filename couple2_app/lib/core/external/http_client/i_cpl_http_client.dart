import 'dart:typed_data';

import 'cpl_http_response.dart';
import 'cpl_http_type_defs.dart';

abstract interface class ICPLHttpClient {
  ICPLHttpClient({
    required this.baseUrl,
    this.receiveTimeout,
    this.connectTimeout,
    this.sendTimeout,
    this.contentType,
  });
  final String baseUrl;
  final Duration? receiveTimeout;
  final Duration? connectTimeout;
  final Duration? sendTimeout;
  final String? contentType;

  void setBaseUrl(String url);

  /// Handy method to make http GET request
  Future<CPLHttpResponse<T>> get<T>(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Handy method to make http POST request
  Future<CPLHttpResponse<T>> post<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Handy method to make http PUT request
  Future<CPLHttpResponse<T>> put<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Handy method to make http DELETE request
  Future<CPLHttpResponse<T>> delete<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Handy method to make http PATCH request
  Future<CPLHttpResponse<T>> patch<T>(
    String path, {
    dynamic data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Handy method to download bytes (for files like PDFs)
  Future<CPLHttpResponse<Uint8List>> getBytes(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  });

  /// Checks whether the device has an active internet connection.
  ///
  /// This method attempts to connect to a reliable internet endpoint (e.g., Google)
  /// to determine if the device is currently online. It returns a `bool` indicating
  /// the availability of an internet connection:
  ///
  /// - `true`: The device is connected to the internet.
  /// - `false`: The device is not connected to the internet or the connection attempt failed.
  ///
  /// This method is typically used before making network requests to ensure that
  /// the device can reach online services.
  ///
  /// Example:
  /// ```dart
  /// bool isOnline = await isInternetAvailable();
  /// if (isOnline) {
  ///   // Proceed with network-dependent operations
  /// } else {
  ///   // Handle the lack of internet connection
  /// }
  /// ```
  Future<bool> isInternetAvailable();
}
