import 'package:core/api/taptap_constants.dart';
import 'package:core/models/game.dart';
import 'package:dio/dio.dart';

import 'taptap_http_client.dart';

/// TapTap app search and lookup. Keyless and unfiltered: the endpoint takes a
/// keyword and an offset, nothing else.
class TapTapSearchApi {
  TapTapSearchApi(this._client);

  final TapTapHttpClient _client;

  /// `from` is a plain offset, so page `n` starts at `(n - 1) * pageSize`.
  ///
  /// The response carries a `total`, but it went missing on a second-page call
  /// while rows kept coming, so paging ends on an empty page — the browse
  /// provider stops there anyway — and the offset ceiling bounds the rest.
  Future<(List<Game>, bool hasMore, int totalPages)> searchGames({
    required String query,
    required int page,
  }) async {
    final int offset = (page - 1) * kTapTapPageSize;
    try {
      final Response<dynamic> resp = await _client.get(
        kTapTapSearchPath,
        queryParameters: <String, dynamic>{
          'kw': query,
          'type': 'app',
          'from': offset,
        },
      );
      final List<Game> games = _parseGames(resp.data);
      final bool hasMore =
          games.isNotEmpty && offset + kTapTapPageSize <= kTapTapMaxOffset;
      return (games, hasMore, hasMore ? page + 1 : page);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search TapTap');
    }
  }

  /// Detail lookup for the refresh path. [id] is the model's shifted id — see
  /// [kTapTapIdOffset] — and comes back as the bare app id on the wire.
  Future<Game?> getGameById(int id) async {
    final int appId = id - kTapTapIdOffset;
    if (appId <= 0) return null;
    try {
      final Response<dynamic> resp = await _client.get(
        kTapTapDetailPath,
        queryParameters: <String, dynamic>{'id': appId},
      );
      final Object? data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      final Object? record = data['data'];
      if (record is! Map<String, dynamic>) return null;
      return Game.fromTapTap(record);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to load the TapTap record');
    }
  }

  /// Rows whose parse throws are dropped rather than failing the whole page.
  List<Game> _parseGames(Object? data) {
    if (data is! Map<String, dynamic>) return const <Game>[];
    final Object? payload = data['data'];
    if (payload is! Map<String, dynamic>) return const <Game>[];
    final Object? list = payload['list'];
    if (list is! List<dynamic>) return const <Game>[];
    final List<Game> games = <Game>[];
    for (final Object? row in list) {
      if (row is! Map<String, dynamic>) continue;
      try {
        games.add(Game.fromTapTap(row));
      } on Object {
        continue;
      }
    }
    return games;
  }
}
