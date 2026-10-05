import 'cpl_http_exception.dart';

class CPLHttpConflictException extends CPLHttpException {
  const CPLHttpConflictException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
