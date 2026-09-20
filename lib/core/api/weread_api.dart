import 'package:core/models/book.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'weread/weread_http_client.dart';
import 'weread/weread_search_api.dart';

export 'weread/weread_types.dart';

final Provider<WeReadApi> wereadApiProvider =
    Provider<WeReadApi>((Ref ref) => WeReadApi());

/// WeRead (weread.qq.com) search facade — the Chinese e-book store, which is
/// where the web-novel and e-book editions OpenLibrary never lists can be
/// found. Keyless, search-only: the catalogue has no by-id endpoint a
/// signed-out client may call.
class WeReadApi {
  WeReadApi({Dio? dio}) : _client = WeReadHttpClient(dio: dio) {
    _search = WeReadSearchApi(_client);
  }

  final WeReadHttpClient _client;
  late final WeReadSearchApi _search;

  Future<(List<Book>, bool hasMore, int totalPages)> searchBooks({
    required String query,
    int page = 1,
  }) =>
      _search.searchBooks(query: query, page: page);

  /// WeRead has no by-id endpoint (`web/book/info` needs a signed-in cookie),
  /// so a stored book is recovered by searching its title again and matching
  /// the bookId. Null when the title no longer surfaces that record.
  Future<Book?> findByNativeId({
    required String title,
    required String nativeId,
  }) =>
      _search.findByNativeId(title: title, nativeId: nativeId);

  void dispose() => _client.dispose();
}
