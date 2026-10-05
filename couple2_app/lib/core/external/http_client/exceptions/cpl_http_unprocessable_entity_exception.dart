import 'cpl_http_exception.dart';

class CPLHttpUnprocessableEntityException extends CPLHttpException {
  const CPLHttpUnprocessableEntityException({
    super.response,
    super.error,
    super.stackTrace,
    super.message,
  });

  CPLUnprocessableEntityModel get data {
    if (response?.data is Map<String, dynamic>) {
      return CPLUnprocessableEntityModel.fromMap(
        response!.data as Map<String, dynamic>,
      );
    }
    throw Exception('Response data is not a valid map');
  }
}

final class CPLUnprocessableEntityModel {
  CPLUnprocessableEntityModel({
    required this.title,
    required this.detail,
    required this.errors,
  });

  factory CPLUnprocessableEntityModel.fromMap(Map<String, dynamic> map) {
    return CPLUnprocessableEntityModel(
      title: map['title'] as String,
      detail: map['detail'] as String,
      errors: (map['errors'] as List<dynamic>)
          .map(
            (e) =>
                CPLUnprocessableErrorModel.fromMap(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
  final String title;
  final String detail;
  final List<CPLUnprocessableErrorModel> errors;
}

final class CPLUnprocessableErrorModel {
  CPLUnprocessableErrorModel({required this.code, required this.description});

  factory CPLUnprocessableErrorModel.fromMap(Map<String, dynamic> map) {
    return CPLUnprocessableErrorModel(
      code: map['code'] as String,
      description: map['description'] as String,
    );
  }
  final String code;
  final String description;
}
