import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../http_client.dart';
import 'dio_extensions.dart';

class DioClient implements ICPLHttpClient {
  DioClient({
    required this.baseUrl,
    this.connectTimeout = CPLHttpConsts.connectTimeout,
    this.receiveTimeout = CPLHttpConsts.receiveTimeout,
    this.sendTimeout = CPLHttpConsts.sendTimeout,
    this.contentType = CPLHttpConsts.contentType,
    this.interceptors,
  }) {
    dio = Dio(
      BaseOptions(
        receiveTimeout: receiveTimeout ?? CPLHttpConsts.receiveTimeout,
        connectTimeout: connectTimeout ?? CPLHttpConsts.connectTimeout,
        sendTimeout: sendTimeout ?? CPLHttpConsts.sendTimeout,
        baseUrl: baseUrl,
        contentType: contentType ?? CPLHttpConsts.contentType,
      ),
    );

    dioForCheckConnection = Dio();
    dio.interceptors.addAll({
      ...interceptors ?? [],
      if (kDebugMode)
        LogInterceptor(
          responseBody: true,
          requestBody: true,
          logPrint: (message) => debugPrint(message.toString()),
        ),
    });
  }

  late Dio dio;

  @visibleForTesting
  late Dio dioForCheckConnection;

  final List<Interceptor>? interceptors;

  @override
  final String baseUrl;

  @override
  final Duration? connectTimeout;

  @override
  final Duration? receiveTimeout;

  @override
  final Duration? sendTimeout;

  @override
  final String? contentType;

  @override
  void setBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  @override
  Future<CPLHttpResponse<T>> delete<T>(
    String path, {
    Object? data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers?.toDioOptions(),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<CPLHttpResponse<T>> get<T>(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: headers?.toDioOptions(),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<CPLHttpResponse<T>> post<T>(
    String path, {
    Object? data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers?.toDioOptions(),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<CPLHttpResponse<T>> put<T>(
    String path, {
    Object? data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers?.toDioOptions(),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<CPLHttpResponse<T>> patch<T>(
    String path, {
    Object? data,
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: headers?.toDioOptions(),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<CPLHttpResponse<Uint8List>> getBytes(
    String path, {
    CPLHttpHeaders? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return (await dio.get<Uint8List>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers, responseType: ResponseType.bytes),
      )).toCPLHttpResponse();
    } on DioException catch (e) {
      throw e.toCPLHttpException();
    }
  }

  @override
  Future<bool> isInternetAvailable() async {
    try {
      final response = await dioForCheckConnection.get<dynamic>(
        'https://www.google.com',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } on DioException {
      return false;
    } on Exception catch (_) {
      return false;
    }
  }
}
