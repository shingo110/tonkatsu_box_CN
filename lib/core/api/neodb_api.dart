import 'package:core/models/book.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'neodb/neodb_http_client.dart';
import 'neodb/neodb_search_api.dart';
import 'neodb/neodb_types.dart';

export 'neodb/neodb_types.dart';

final Provider<NeoDBApi> neodbApiProvider =
    Provider<NeoDBApi>((Ref ref) => NeoDBApi());

/// NeoDB (neodb.social) REST facade — a federated Chinese-language catalog
/// whose `external_resources` carry the matching Douban / Goodreads links,
/// which is what makes it usable here without touching Douban directly.
class NeoDBApi {
  NeoDBApi({Dio? dio}) : _client = NeoDBHttpClient(dio: dio) {
    _search = NeoDBSearchApi(_client);
  }

  final NeoDBHttpClient _client;
  late final NeoDBSearchApi _search;

  Future<(List<Book>, bool hasMore, int totalPages)> searchBooks({
    required String query,
    int page = 1,
  }) =>
      _search.searchItems(query: query, category: kNeoDBBookCategory, page: page);

  /// [uuid] is the NeoDB uuid, not the numeric [Book.id].
  Future<Book?> getBookById(String uuid) => _search.getItem(uuid);

  void dispose() => _client.dispose();
}
