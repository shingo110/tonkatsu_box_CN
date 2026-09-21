import 'dart:convert';

import 'package:core/api/psn_constants.dart';
import 'package:dio/dio.dart';

import '../../../shared/constants/platform_features.dart';
import '../api_dio.dart';
import '../api_error_detail.dart';
import 'psn_types.dart';

/// Reads the account's purchase history out of the web store's GraphQL host.
///
/// This is the one PSN surface that answers "what have I bought": the trophy
/// list only covers titles that were played, and the gamelist is per-device.
/// The query is a *persisted* one — Sony stores the document server-side and
/// the request carries nothing but its name, a sha256 and the variables — so
/// there is no GraphQL text to keep in sync here.
class PsnLibraryClient {
  PsnLibraryClient({Dio? dio})
      : _dio = dio ??
            createApiDio(
              baseUrl: kPsnWebBase,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            );

  final Dio _dio;

  /// Every purchased PS4/PS5 title, paged until a short page arrives.
  ///
  /// Rows are deduped on the display name: the store lists one entry per
  /// platform version, and the same game bought for PS4 and PS5 is one line in
  /// the user's library, not two.
  Future<List<PsnPurchasedGame>> fetchPurchasedGames({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) async {
    final String token = accessToken.trim();
    if (token.isEmpty) {
      throw const PsnApiException('PlayStation account is not connected');
    }

    final List<PsnPurchasedGame> games = <PsnPurchasedGame>[];
    final Set<String> seen = <String>{};

    for (int page = 0; page < kPsnPurchasedMaxPages; page++) {
      final List<PsnPurchasedGame> batch = await _fetchPage(
        token: token,
        start: page * kPsnPurchasedPageSize,
      );
      for (final PsnPurchasedGame game in batch) {
        if (game.isUsable && seen.add(game.name.trim().toLowerCase())) {
          games.add(game);
        }
      }
      onPage?.call(games.length);
      if (batch.length < kPsnPurchasedPageSize) break;
    }

    return games;
  }

  Future<List<PsnPurchasedGame>> _fetchPage({
    required String token,
    required int start,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'operationName': kPsnPurchasedGameListOperation,
      'variables': jsonEncode(<String, dynamic>{
        'isActive': true,
        'platform': <String>['ps4', 'ps5'],
        'size': kPsnPurchasedPageSize,
        'start': start,
        'sortBy': 'ACTIVE_DATE',
        'sortDirection': 'desc',
      }),
      'extensions': jsonEncode(<String, dynamic>{
        'persistedQuery': <String, dynamic>{
          'version': 1,
          'sha256Hash': kPsnPurchasedGameListHash,
        },
      }),
    };
    if (kIsWebBuild) {
      // A browser cannot be relied on to carry an Authorization header through
      // the proxy, so on web the token rides the URL and the server moves it
      // back into the header. Desktop and mobile send the real one.
      query[kPsnAccessTokenParam] = token;
    }

    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        kPsnGraphqlPath,
        queryParameters: query,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $token'},
          // GraphQL reports a rejected token as 200 with an `errors` array and
          // a refused one as 400; both need the body, not an exception.
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final Object? data = response.data;
      if (data is! Map<String, dynamic>) {
        throw PsnApiException(
          'PlayStation returned an unexpected response',
          statusCode: response.statusCode,
        );
      }

      final List<PsnPurchasedGame> games = _gamesFrom(data);
      // GraphQL reports a rejected token with HTTP 200 and an `errors` array,
      // so an empty list is not the same as a successful empty library.
      final Object? errors = data['errors'];
      if (games.isEmpty && errors is List<dynamic>) {
        throw PsnApiException(
          _firstErrorMessage(errors) ??
              'PlayStation rejected the purchase list request',
          statusCode: response.statusCode,
        );
      }
      return games;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  static List<PsnPurchasedGame> _gamesFrom(Map<String, dynamic> body) {
    final Map<String, dynamic>? data = body['data'] as Map<String, dynamic>?;
    final Map<String, dynamic>? retrieved =
        data?['purchasedTitlesRetrieve'] as Map<String, dynamic>?;
    final List<dynamic> rows =
        (retrieved?['games'] as List<dynamic>?) ?? <dynamic>[];

    return <PsnPurchasedGame>[
      for (final Object? row in rows)
        if (row is Map<String, dynamic>) PsnPurchasedGame.fromJson(row),
    ];
  }

  static String? _firstErrorMessage(List<dynamic> errors) {
    for (final Object? error in errors) {
      if (error is Map<String, dynamic>) {
        final Object? message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    }
    return null;
  }

  PsnApiException _mapError(DioException e) {
    final int? statusCode = e.response?.statusCode;
    String message = 'Could not read the PlayStation library';
    if (statusCode == 401 || statusCode == 403) {
      message = 'The PlayStation session expired. Sign in again';
    } else if (statusCode == 400) {
      message = 'PlayStation refused the library request';
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
