// ignore_for_file: no_default_cases

import 'package:dio/dio.dart';

import '../../exceptions/exceptions.dart';
import '../../cpl_http_response.dart';
import '../../cpl_http_type_defs.dart';

extension CPLHttpDioResponseX<T> on Response<T> {
  CPLHttpResponse<T> toCPLHttpResponse() {
    return CPLHttpResponse<T>(
      data: data,
      headers: headers.map,
      statusCode: statusCode,
      statusMessage: statusMessage,
    );
  }
}

extension CPLHttpDioExceptionX<T> on DioException {
  CPLHttpException toCPLHttpException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const CPLHttpDeadlineExceededException();
      case DioExceptionType.connectionError:
        return _offline();
      default:
        final offlineBlob = '${message ?? ''} ${error ?? ''}'.toLowerCase();
        if (response?.statusCode != 400 &&
            (response == null || _isOfflineBlob(offlineBlob))) {
          return _offline();
        }

        switch (response?.statusCode) {
          case 400:
            return CPLHttpBadRequestException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );

          case 401:
            return CPLHttpUnauthorizedException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
          case 403:
            return CPLHttpForbiddenException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
          case 404:
            return CPLHttpNotFoundException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
          case 409:
            return CPLHttpConflictException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
          case 422:
            return CPLHttpUnprocessableEntityException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
          case (!= null && >= 500 && <= 599):
            return CPLHttpInternalServerErrorException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );

          default:
            return CPLHttpException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: message,
            );
        }
    }
  }

  CPLHttpNoInternetConnectionException _offline() {
    return CPLHttpNoInternetConnectionException(
      response: CPLHttpResponse(
        data: response?.data,
        headers: response?.headers.map,
        statusCode: response?.statusCode,
        statusMessage: response?.statusMessage,
      ),
      error: error,
      stackTrace: stackTrace,
      message: 'Sem conexão. Verifique a internet e tente de novo.',
    );
  }
}

bool _isOfflineBlob(String raw) {
  return raw.contains('failed host lookup') ||
      raw.contains('connection abort') ||
      raw.contains('connection refused') ||
      raw.contains('connection errored') ||
      raw.contains('connection error') ||
      raw.contains('xmlhttprequest') ||
      raw.contains('network is unreachable') ||
      raw.contains('failed to fetch') ||
      raw.contains('socketexception');
}

extension CPLHttpHeadersX<T> on CPLHttpHeaders {
  Options toDioOptions() {
    return Options(headers: this);
  }
}
