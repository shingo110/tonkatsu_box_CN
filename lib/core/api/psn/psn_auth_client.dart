import 'package:core/api/psn_constants.dart';
import 'package:dio/dio.dart';

import '../../../shared/constants/platform_features.dart';
import '../api_dio.dart';
import '../api_error_detail.dart';
import 'psn_types.dart';

/// The two steps that turn an NPSSO into a JWT.
///
/// PSN has no PIN flow and no OAuth registration, so this is the whole of the
/// authorisation: an NPSSO cookie buys a one-shot code, the code buys an access
/// token plus a refresh token. Nothing here listens on a redirect — the code is
/// read straight out of a `Location` header, which is why the flow works on
/// desktop, mobile and web alike and needs no WebView or deep link.
class PsnAuthClient {
  PsnAuthClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: kPsnAuthBase,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            );

  final Dio _dio;

  /// Step one. The redirect target belongs to the PlayStation App, so the 302
  /// is never followed — the code in its `Location` header is the whole point.
  Future<String> exchangeNpssoForCode(String npsso) async {
    final String trimmed = npsso.trim();
    if (trimmed.isEmpty) {
      throw const PsnApiException('Enter an NPSSO first');
    }

    final Map<String, dynamic> query = <String, dynamic>{
      'access_type': 'offline',
      'client_id': kPsnClientId,
      'redirect_uri': kPsnRedirectUri,
      'response_type': 'code',
      'scope': kPsnScope,
    };
    final Map<String, String> headers = <String, String>{};
    if (kIsWebBuild) {
      // A browser strips a Cookie header on the way out, so on web the value
      // rides the URL and the selfhost proxy turns it back into a header. A
      // desktop or mobile build talks to Sony directly and sends the real one.
      query[kPsnNpssoParam] = trimmed;
    } else {
      headers['Cookie'] = 'npsso=$trimmed';
    }

    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        kPsnAuthorizePath,
        queryParameters: query,
        options: Options(
          headers: headers,
          followRedirects: false,
          // A 302 is the success case here, so it must not be raised.
          validateStatus: (int? status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      return _codeFrom(response.headers.value('location'));
    } on DioException catch (e) {
      throw _mapError(e, 'Sony rejected the sign-in');
    }
  }

  /// Step two.
  Future<PsnAuthTokens> exchangeCodeForTokens(String code) =>
      _postToken(<String, String>{
        'code': code,
        'redirect_uri': kPsnRedirectUri,
        'grant_type': 'authorization_code',
        'token_format': 'jwt',
      });

  /// Keeps a connected account alive without asking for the NPSSO again. The
  /// refresh token lasts about two months, and the NPSSO never leaves memory.
  Future<PsnAuthTokens> refresh(String refreshToken) {
    final String trimmed = refreshToken.trim();
    if (trimmed.isEmpty) {
      throw const PsnApiException('No PlayStation refresh token');
    }
    return _postToken(<String, String>{
      'refresh_token': trimmed,
      'grant_type': 'refresh_token',
      'token_format': 'jwt',
      'scope': kPsnScope,
    });
  }

  Future<PsnAuthTokens> _postToken(Map<String, String> body) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        kPsnTokenPath,
        data: body,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          // The pair is public and fixed; on web the proxy re-supplies it
          // anyway, because it forwards no Authorization of its own accord.
          headers: <String, String>{'Authorization': kPsnBasicAuth},
          // Sony answers a rejected code with 400 `invalid_grant` and the body
          // is the only useful part of that, so it must not be raised away.
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final Object? data = response.data;
      if (response.statusCode != 200 || data is! Map<String, dynamic>) {
        throw _tokenFailure(response);
      }
      final PsnAuthTokens tokens = PsnAuthTokens.fromJson(data);
      if (!tokens.isUsable) {
        throw const PsnApiException('Sony returned no usable token');
      }
      return tokens;
    } on DioException catch (e) {
      throw _mapError(e, 'Could not obtain a PlayStation token');
    }
  }

  /// Pulls the code out of the redirect target. An empty result is a refusal,
  /// not a malformed response: Sony bounces an unusable NPSSO to the sign-in
  /// page instead of failing the request.
  String _codeFrom(String? location) {
    if (location == null || location.isEmpty) {
      throw const PsnApiException('Sony returned no sign-in redirect');
    }
    final int mark = location.indexOf('?');
    final Map<String, String> params = mark < 0
        ? const <String, String>{}
        : Uri.splitQueryString(location.substring(mark + 1));
    final String? code = params['code'];
    if (code == null || code.isEmpty) {
      throw const PsnApiException(
        'The NPSSO was refused. Sign in at playstation.com again and copy a '
        'fresh one',
      );
    }
    return code;
  }

  /// Surfaces Sony's own `error_description` — it names the actual fault
  /// (`invalid_grant`, `invalid_client`) where a generic message would not.
  PsnApiException _tokenFailure(Response<dynamic> response) {
    final Object? data = response.data;
    String? description;
    if (data is Map<String, dynamic>) {
      description = (data['error_description'] as String?) ??
          (data['error'] as String?);
    }
    return PsnApiException(
      (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : 'Sony refused the PlayStation credentials',
      statusCode: response.statusCode,
    );
  }

  PsnApiException _mapError(DioException e, String defaultMessage) {
    final int? statusCode = e.response?.statusCode;
    String message = defaultMessage;
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      message = 'Sony refused the PlayStation credentials. Sign in again';
    } else if (statusCode == 429) {
      message = 'PlayStation rate limit reached. Try again later';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection to Sony timed out';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return PsnApiException(
      message,
      statusCode: statusCode,
      detail: buildApiErrorDetail(
        apiName: 'PlayStation',
        exception: e,
        userMessage: message,
      ),
    );
  }

  void dispose() => _dio.close();
}
