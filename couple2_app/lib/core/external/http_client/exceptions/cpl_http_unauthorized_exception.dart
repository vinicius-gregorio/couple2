import 'cpl_http_exception.dart';

class CPLHttpUnauthorizedException extends CPLHttpException {
  const CPLHttpUnauthorizedException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
