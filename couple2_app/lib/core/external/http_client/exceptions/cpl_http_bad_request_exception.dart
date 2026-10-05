import 'cpl_http_exception.dart';

class CPLHttpBadRequestException extends CPLHttpException {
  const CPLHttpBadRequestException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });

  String? get errorDescription {
    if (response?.data is! Map<String, dynamic>) return null;
    final data = response!.data as Map<String, dynamic>;
    final errors = data['errors'];
    if (errors is! List || errors.isEmpty) return null;
    final firstError = errors[0];
    if (firstError is! Map<String, dynamic>) return null;
    final description = firstError['description'];
    if (description is String) return description;
    return null;
  }
}
