import 'package:core/api/taptap_constants.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import '../api_error_detail.dart';
import 'taptap_types.dart';

// TapTap transport (https://www.taptap.cn). Keyless, but not headerless: the
// endpoint answers `400 INVALID_XUA` to anything without `X-UA`, which is why
// the header rides in the base options. Fifteen back-to-back searches all
// returned 200, so there is nothing here to back off from.
class TapTapHttpClient {
  TapTapHttpClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: 'https://$kTapTapHost/',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'User-Agent': kAppUserAgent,
                'Accept': 'application/json',
                'X-UA': kTapTapXUa,
              },
            );

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    required Map<String, dynamic> queryParameters,
  }) {
    return _dio.get<dynamic>(path, queryParameters: queryParameters);
  }

  TapTapApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400) {
      // The one 400 this client can earn is a stripped `X-UA` — on web the
      // proxy has to forward it, since the browser sets no custom UA.
      message = 'TapTap refused the request (missing client header)';
    } else if (statusCode == 404) {
      message = 'Not found';
    } else if (statusCode == 429) {
      message = 'TapTap rate limit exceeded. Please try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return TapTapApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.taptap.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() {
    _dio.close();
  }
}
