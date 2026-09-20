import 'package:core/models/book.dart';
import 'package:dio/dio.dart';

import 'neodb_http_client.dart';
import 'neodb_types.dart';

/// NeoDB catalog search. Keyless; 25 back-to-back searches all answered 200,
/// but responses take ~1s, so the caller paces the follow-up pages.
class NeoDBSearchApi {
  NeoDBSearchApi(this._client);

  final NeoDBHttpClient _client;

  /// `query` is mandatory: omitting it is a 422 and an empty string a 400,
  /// so this endpoint can only search, never browse.
  Future<(List<Book>, bool hasMore, int totalPages)> searchItems({
    required String query,
    String category = kNeoDBBookCategory,
    int page = 1,
  }) async {
    try {
      final Response<dynamic> resp = await _client.get(
        'api/catalog/search',
        queryParameters: <String, dynamic>{
          'query': query,
          'category': category,
          'page': page,
        },
      );
      final Map<String, dynamic> data =
          (resp.data as Map<String, dynamic>?) ?? <String, dynamic>{};
      final List<Book> items = _parseItems(data['data']);

      // Pages collapse editions of one work, so their row count varies
      // (6, 11, 19 over three pages in testing) while `pages` stays honest —
      // never derive either number from the row count.
      final int pages = (data['pages'] as num?)?.toInt() ?? 1;
      final bool hasMore = page < pages;

      return (items, hasMore, pages < 1 ? 1 : pages);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search NeoDB');
    }
  }

  /// Item detail by uuid. Search rows already carry the full payload, so this
  /// serves the refresh path and the `.xcoll` import re-fetch.
  Future<Book?> getItem(
    String uuid, {
    String category = kNeoDBBookCategory,
  }) async {
    try {
      final Response<dynamic> resp = await _client.get('api/$category/$uuid');
      final Object? data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      return _tryParse(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _client.handleDioException(e, 'Failed to load the NeoDB item');
    }
  }

  /// One malformed row is dropped instead of failing the whole page.
  static List<Book> _parseItems(Object? rows) {
    if (rows is! List<dynamic>) return <Book>[];
    final List<Book> out = <Book>[];
    for (final Object? row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final Book? book = _tryParse(row);
      if (book != null) out.add(book);
    }
    return out;
  }

  static Book? _tryParse(Map<String, dynamic> json) {
    try {
      return Book.fromNeoDBItem(json);
    } on Object {
      return null;
    }
  }
}
