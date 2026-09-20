import 'package:core/api/douban_constants.dart';
import 'package:core/api/douban_signature.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';

import '../../../shared/constants/platform_features.dart';
import '../api_dio.dart';
import '../api_error_detail.dart';
import '../host_rate_limiter.dart';
import 'douban_types.dart';

/// Adds `apiKey`, `_ts` and `_sig` to every request. The signature covers the
/// request path and the current time and expires within minutes, so it is
/// computed per request rather than per client.
class DoubanAuthInterceptor extends Interceptor {
  DoubanAuthInterceptor({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String? _apiKey;
  String? _secret;

  void setCredentials(String apiKey, String secret) {
    _apiKey = apiKey;
    _secret = secret;
  }

  void clearCredentials() {
    _apiKey = null;
    _secret = null;
  }

  bool get hasCredentials =>
      _apiKey != null &&
      _apiKey!.isNotEmpty &&
      _secret != null &&
      _secret!.isNotEmpty;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // The browser never holds the secret; the selfhost proxy signs instead.
    if (!kIsWebBuild && hasCredentials) {
      final int unixTime = _now().millisecondsSinceEpoch ~/ 1000;
      options.queryParameters['apiKey'] = _apiKey;
      options.queryParameters['_ts'] = unixTime;
      options.queryParameters['_sig'] =
          doubanSignature(_secret!, options.path, unixTime);
    }
    handler.next(options);
  }
}

/// Every request is signed, and Frodo answers 403 to a wrong pair as well as
/// to a User-Agent that is not the shipped client's.
class DoubanHttpClient {
  DoubanHttpClient({Dio? dio, DateTime Function()? now})
      : _auth = DoubanAuthInterceptor(now: now),
        _dio = dio ??
            createApiDio(
              baseUrl: kDoubanApiBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: const <String, String>{'User-Agent': kDoubanUserAgent},
            ) {
    _dio.interceptors.add(_auth);
  }

  final Dio _dio;
  final DoubanAuthInterceptor _auth;

  void setCredentials(String apiKey, String secret) =>
      _auth.setCredentials(apiKey, secret);

  void clearCredentials() => _auth.clearCredentials();

  bool get hasCredentials => _auth.hasCredentials;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<dynamic>(path, queryParameters: queryParameters);

  DoubanApiException handleDioException(
    DioException e,
    String defaultMessage,
  ) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    // The breaker refuses before anything leaves, so its wording is the only
    // one that tells the user what to do about it.
    if (e.error case final HostCooldownException cooldown) {
      message = 'Rate limit exceeded for ${cooldown.host}. '
          'Try again in ${cooldown.remainingSeconds}s';
    } else if (statusCode == 403) {
      // Frodo answers 403 for a wrong pair and for a banned client alike, so
      // name the two things the user controls: the pair, then the wait.
      message = 'Douban refused the request. Check the API key and secret, '
          'then wait a few minutes before retrying';
    } else if (statusCode == 401) {
      message = 'Douban rejected the request signature. '
          'Check the API key and secret';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return DoubanApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: DataSource.douban.label,
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() => _dio.close();
}
