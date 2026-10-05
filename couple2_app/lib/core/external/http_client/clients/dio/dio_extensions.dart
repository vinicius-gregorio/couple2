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
      default:
        if (response?.statusCode != 400) {
          final errorMessage =
              message?.toLowerCase() ?? error?.toString().toLowerCase();
          if ((errorMessage?.contains('failed host lookup') ?? false) ||
              (errorMessage?.contains('connection abort') ?? false)) {
            return CPLHttpNoInternetConnectionException(
              response: CPLHttpResponse(
                data: response?.data,
                headers: response?.headers.map,
                statusCode: response?.statusCode,
                statusMessage: response?.statusMessage,
              ),
              error: error,
              stackTrace: stackTrace,
              message: 'Error connecting to the server',
            );
          }
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
}

extension CPLHttpHeadersX<T> on CPLHttpHeaders {
  Options toDioOptions() {
    return Options(headers: this);
  }
}
