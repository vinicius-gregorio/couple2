import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Attaches the app JWT saved at login. Session and couple calls depend on it.
class AuthTokenInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
