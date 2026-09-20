import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import '../api_error_detail.dart';
import 'neodb_types.dart';

// NeoDB transport (https://neodb.social). Unlike Bangumi it answers 200 even to
// a default User-Agent — the header here is identification, not a requirement.
class NeoDBHttpClient {
  NeoDBHttpClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: 'https://neodb.social/',
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

  NeoDBApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400) {
      message = 'NeoDB rejected the request';
    } else if (statusCode == 404) {
      message = 'Not found';
    } else if (statusCode == 422) {
      // A missing `query` param is a 422 — NeoDB has no filter-only browse.
      message = 'NeoDB needs a search keyword';
    } else if (statusCode == 429) {
      message = 'Rate limit exceeded. Please try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return NeoDBApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.neodb.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() {
    _dio.close();
  }
}
