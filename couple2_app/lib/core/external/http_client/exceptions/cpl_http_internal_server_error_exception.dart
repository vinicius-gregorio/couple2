import 'cpl_http_exception.dart';

class CPLHttpInternalServerErrorException extends CPLHttpException {
  const CPLHttpInternalServerErrorException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });
}
