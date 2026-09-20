import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import '../api_error_detail.dart';
import 'weread_types.dart';

// WeRead transport (https://weread.qq.com). Keyless and, like NeoDB, it answers
// content to any User-Agent — the header here is identification, not a
// requirement. (Probing through a sandbox proxy once returned an empty body,
// which reads as a User-Agent refusal; the same request sent directly is 200.)
class WeReadHttpClient {
  WeReadHttpClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: 'https://weread.qq.com/',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'User-Agent': kAppUserAgent,
                'Accept': 'application/json',
              },
            );

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<dynamic>(path, queryParameters: queryParameters);
  }

  WeReadApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400) {
      message = 'WeRead rejected the request';
    } else if (statusCode == 404) {
      message = 'Not found';
    } else if (statusCode == 429) {
      message = 'Rate limit exceeded. Please try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return WeReadApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.weread.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() {
    _dio.close();
  }
}
