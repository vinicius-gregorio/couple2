import 'cpl_http_exception.dart';

class CPLHttpForbiddenException extends CPLHttpException {
  const CPLHttpForbiddenException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
