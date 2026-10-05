import 'cpl_http_exception.dart';

class CPLHttpDeadlineExceededException extends CPLHttpException {
  const CPLHttpDeadlineExceededException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
