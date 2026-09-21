import 'package:core/api/ximalaya_constants.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import '../api_error_detail.dart';
import 'ximalaya_types.dart';

// Ximalaya transport (https://www.ximalaya.com). Keyless, but the host sits
// behind a risk engine: `/revision/search/main` answers `risk invalid` to a
// bare client, while `/revision/search/seo` — the path the site's own front end
// calls — answers plain JSON to the same headers. A `Referer` is sent because
// the front end always has one. Twelve back-to-back searches all returned 200.
//
// The body is JSON but the header says `text/plain`, which defeats Dio's
// sniffing and hands back a String — read as text and decode via
// [decodeJsonBody], as Fantlab does for its own mislabelled content type.
class XimalayaHttpClient {
  XimalayaHttpClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: 'https://$kXimalayaHost/',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'User-Agent': kAppUserAgent,
                'Accept': 'application/json',
                'Referer': 'https://$kXimalayaHost/',
              },
              responseType: ResponseType.plain,
            );

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    required Map<String, dynamic> queryParameters,
  }) {
    return _dio.get<dynamic>(path, queryParameters: queryParameters);
  }

  XimalayaApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400) {
      message = 'Ximalaya rejected the request';
    } else if (statusCode == 404) {
      message = 'Not found';
    } else if (statusCode == 429) {
      message = 'Ximalaya rate limit exceeded. Please try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return XimalayaApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.ximalaya.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() {
    _dio.close();
  }
}
