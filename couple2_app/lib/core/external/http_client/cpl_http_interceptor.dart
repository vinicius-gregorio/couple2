import 'package:dio/dio.dart';

class CPLHttpInterceptor extends InterceptorsWrapper {
  CPLHttpInterceptor({super.onRequest, super.onResponse, super.onError});
}
