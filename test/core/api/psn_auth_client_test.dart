import 'package:core/api/psn_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/psn/psn_auth_client.dart';
import 'package:tonkatsu_box/core/api/psn/psn_types.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late PsnAuthClient client;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    client = PsnAuthClient(dio: mockDio);
  });

  Response<dynamic> makeResponse(
    Object? data, {
    int status = 200,
    Map<String, String> headers = const <String, String>{},
  }) =>
      Response<dynamic>(
        data: data,
        statusCode: status,
        headers: Headers.fromMap(<String, List<String>>{
          for (final MapEntry<String, String> e in headers.entries)
            e.key: <String>[e.value],
        }),
        requestOptions: RequestOptions(path: ''),
      );

  void stubGet(Response<dynamic> response) {
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => response);
  }

  void stubPost(Response<dynamic> response) {
    when(() => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => response);
  }

  /// The [Options] the client actually built, so flags like
  /// `followRedirects` can be asserted — a `RequestOptions` rebuilt here would
  /// silently carry the defaults instead.
  Options capturedGetOptions() {
    return verify(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        )).captured.single as Options;
  }

  Map<String, dynamic> capturedGetQuery() {
    return verify(() => mockDio.get<dynamic>(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        )).captured.single as Map<String, dynamic>;
  }

  group('exchangeNpssoForCode', () {
    test('reads the code out of the redirect Location without following it',
        () async {
      stubGet(makeResponse(
        null,
        status: 302,
        headers: <String, String>{
          'location': '$kPsnRedirectUri?code=v3.abc123',
        },
      ));

      final String code = await client.exchangeNpssoForCode('my-npsso');

      expect(code, 'v3.abc123');
      expect(capturedGetOptions().followRedirects, isFalse);    });

    test('asks for exactly the scopes and redirect the app registers',
        () async {
      stubGet(makeResponse(
        null,
        status: 302,
        headers: <String, String>{'location': '$kPsnRedirectUri?code=x'},
      ));

      await client.exchangeNpssoForCode('my-npsso');

      final Map<String, dynamic> query = capturedGetQuery();
      expect(query['client_id'], kPsnClientId);
      expect(query['redirect_uri'], kPsnRedirectUri);
      expect(query['response_type'], 'code');
      expect(query['access_type'], 'offline');
      expect(query['scope'], kPsnScope);
    });

    test('sends the NPSSO as a Cookie header off web builds', () async {
      stubGet(makeResponse(
        null,
        status: 302,
        headers: <String, String>{'location': '$kPsnRedirectUri?code=x'},
      ));

      await client.exchangeNpssoForCode('  my-npsso  ');

      // Trimmed, because a copied cookie arrives with whatever whitespace the
      // clipboard carried.
      expect(capturedGetOptions().headers?['Cookie'], 'npsso=my-npsso');
    });

    test('treats a redirect without a code as a refused NPSSO', () async {
      stubGet(makeResponse(
        null,
        status: 302,
        headers: <String, String>{
          'location': 'https://my.account.sony.com/central/signin/',
        },
      ));

      expect(
        () => client.exchangeNpssoForCode('stale'),
        throwsA(
          isA<PsnApiException>().having(
            (PsnApiException e) => e.message,
            'message',
            contains('refused'),
          ),
        ),
      );
    });

    test('rejects a blank NPSSO before spending a request', () async {
      expect(
        () => client.exchangeNpssoForCode('   '),
        throwsA(isA<PsnApiException>()),
      );
      verifyNever(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ));
    });

    test('maps a transport failure to a readable message', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => client.exchangeNpssoForCode('npsso'),
        throwsA(
          isA<PsnApiException>().having(
            (PsnApiException e) => e.message,
            'message',
            'No internet connection',
          ),
        ),
      );
    });
  });

  group('exchangeCodeForTokens', () {
    test('parses the token pair', () async {
      stubPost(makeResponse(<String, dynamic>{
        'access_token': 'at',
        'refresh_token': 'rt',
        'expires_in': 3600,
        'refresh_token_expires_in': 5184000,
      }));

      final PsnAuthTokens tokens = await client.exchangeCodeForTokens('code');

      expect(tokens.accessToken, 'at');
      expect(tokens.refreshToken, 'rt');
      expect(tokens.expiresIn, 3600);
      expect(tokens.refreshTokenExpiresIn, 5184000);
      expect(tokens.isUsable, isTrue);
    });

    test('signs the exchange with the shipped public client pair', () async {
      stubPost(makeResponse(<String, dynamic>{
        'access_token': 'at',
        'refresh_token': 'rt',
      }));

      await client.exchangeCodeForTokens('code');

      final Options options = verify(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
          )).captured.single as Options;
      expect(options.headers?['Authorization'], kPsnBasicAuth);
      expect(options.contentType, Headers.formUrlEncodedContentType);
    });

    test('surfaces Sony error_description rather than a generic message',
        () async {
      stubPost(makeResponse(
        <String, dynamic>{
          'error': 'invalid_grant',
          'error_description': 'Grant type is invalid',
        },
        status: 400,
      ));

      expect(
        () => client.exchangeCodeForTokens('spent'),
        throwsA(
          isA<PsnApiException>()
              .having((PsnApiException e) => e.message, 'message',
                  'Grant type is invalid')
              .having((PsnApiException e) => e.statusCode, 'status', 400),
        ),
      );
    });

    test('reports a body that carries no usable token', () async {
      stubPost(makeResponse(<String, dynamic>{'expires_in': 3600}));

      expect(
        () => client.exchangeCodeForTokens('code'),
        throwsA(isA<PsnApiException>()),
      );
    });
  });

  group('refresh', () {
    test('asks for the same scopes under the refresh grant', () async {
      stubPost(makeResponse(<String, dynamic>{
        'access_token': 'at2',
        'refresh_token': 'rt2',
      }));

      final PsnAuthTokens tokens = await client.refresh('rt');

      expect(tokens.refreshToken, 'rt2');

      final Map<String, dynamic> body = verify(() => mockDio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          )).captured.single as Map<String, dynamic>;
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'rt');
      expect(body['scope'], kPsnScope);
    });

    test('refuses an empty refresh token without a request', () async {
      expect(() => client.refresh(' '), throwsA(isA<PsnApiException>()));
      verifyNever(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ));
    });
  });
}
