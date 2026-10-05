import 'cpl_http_exception.dart';

class CPLHttpNoInternetConnectionException extends CPLHttpException {
  const CPLHttpNoInternetConnectionException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
