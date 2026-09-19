import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import '../api_error_detail.dart';
import 'bangumi_types.dart';

// Bangumi transport (https://api.bgm.tv). Keyless, but the API sits behind
// Cloudflare, which answers 403 to any request without a real User-Agent.
class BangumiHttpClient {
  BangumiHttpClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: 'https://api.bgm.tv/',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const <String, String>{'User-Agent': kAppUserAgent},
            );

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<dynamic>(path, queryParameters: queryParameters);
  }

  /// Search is a POST: the filter DSL is a nested object and does not fit a
  /// query string.
  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? queryParameters,
    required Map<String, dynamic> body,
  }) {
    return _dio.post<dynamic>(
      path,
      queryParameters: queryParameters,
      data: body,
    );
  }

  BangumiApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400) {
      message = 'Bangumi rejected the search filters';
    } else if (statusCode == 404) {
      message = 'Not found';
    } else if (statusCode == 403) {
      // Cloudflare's blanket refusal, usually a missing or blocked User-Agent.
      message = 'Bangumi refused the request';
    } else if (statusCode == 429) {
      message = 'Rate limit exceeded. Please try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return BangumiApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.bangumi.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() {
    _dio.close();
  }
}
