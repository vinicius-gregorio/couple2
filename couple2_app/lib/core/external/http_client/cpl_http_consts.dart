import '../../net/request_timeout.dart';

class CPLHttpConsts {
  static const Duration connectTimeout = requestTimeout;
  static const Duration receiveTimeout = requestTimeout;
  static const Duration sendTimeout = requestTimeout;

  static const contentType = 'application/json; charset=utf-8';
}
