import 'dart:convert';

class CPLHttpResponse<T> {
  CPLHttpResponse({
    required this.data,
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
  });

  final T? data;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>>? headers;

  @override
  String toString() {
    if (data is Map) {
      // Log encoded maps for better readability.
      return json.encode(data);
    }
    return data.toString();
  }
}
