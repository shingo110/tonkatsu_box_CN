import 'package:core/models/game.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'taptap/taptap_http_client.dart';
import 'taptap/taptap_search_api.dart';

export 'taptap/taptap_types.dart';

final Provider<TapTapApi> tapTapApiProvider =
    Provider<TapTapApi>((Ref ref) => TapTapApi());

/// TapTap (taptap.cn) facade — the one games catalogue a mainland-China
/// network reaches without a proxy, and the only source here whose titles,
/// tags and descriptions are Chinese by construction. Keyless, search-only:
/// the search endpoint needs a keyword and no browse endpoint exists.
class TapTapApi {
  TapTapApi({Dio? dio}) : _client = TapTapHttpClient(dio: dio) {
    _search = TapTapSearchApi(_client);
  }

  final TapTapHttpClient _client;
  late final TapTapSearchApi _search;

  Future<(List<Game>, bool hasMore, int totalPages)> searchGames({
    required String query,
    required int page,
  }) =>
      _search.searchGames(query: query, page: page);

  /// [id] is the model's **shifted** id — the one `Game.id` carries and
  /// `collection_items.external_id` stores — not the bare app id in the URL.
  Future<Game?> getGameById(int id) => _search.getGameById(id);

  void dispose() => _client.dispose();
}
