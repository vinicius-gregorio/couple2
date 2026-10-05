import '../cpl_http_response.dart';

class CPLHttpException implements Exception {
  const CPLHttpException({
    this.response,
    this.error,
    this.stackTrace,
    this.message,
  });

  final CPLHttpResponse<dynamic>? response;
  final Object? error;
  final StackTrace? stackTrace;
  final String? message;

  @override
  String toString() {
    return [
      '$CPLHttpException: $message',
      if (error is Error) '${(error! as Error).stackTrace}',
      'Source stack:\n$stackTrace',
    ].join('\n');
  }
}
