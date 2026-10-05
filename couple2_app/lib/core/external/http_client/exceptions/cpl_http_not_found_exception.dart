import 'cpl_http_exception.dart';

class CPLHttpNotFoundException extends CPLHttpException {
  const CPLHttpNotFoundException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
