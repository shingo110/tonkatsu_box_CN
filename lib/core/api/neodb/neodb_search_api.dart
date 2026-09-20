import 'package:dio/dio.dart';

import 'neodb_http_client.dart';

/// NeoDB catalog search. Keyless; 25 back-to-back searches all answered 200,
/// but responses take ~1s, so the caller paces the follow-up pages.
///
/// The three media mappings share this class: only the category token and the
/// row parser differ, so books, movies and TV all ride one request path.
class NeoDBSearchApi {
  NeoDBSearchApi(this._client);

  final NeoDBHttpClient _client;

  /// `query` is mandatory: omitting it is a 422 and an empty string a 400,
  /// so this endpoint can only search, never browse.
  Future<(List<T>, bool hasMore, int totalPages)> search<T>({
    required String query,
    required String category,
    required T Function(Map<String, dynamic> json) parse,
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
      final List<T> items = _parseItems(data['data'], parse);

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
  /// serves the refresh path and the `.xcoll` import re-fetch. [segment] is
  /// how a TV season is addressed (`/api/tv/season/{uuid}`).
  Future<T?> getItem<T>(
    String uuid, {
    required String category,
    required T Function(Map<String, dynamic> json) parse,
    String? segment,
  }) async {
    final String path = segment == null
        ? 'api/$category/$uuid'
        : 'api/$category/$segment/$uuid';
    try {
      final Response<dynamic> resp = await _client.get(path);
      final Object? data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      return _tryParse(data, parse);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _client.handleDioException(e, 'Failed to load the NeoDB item');
    }
  }

  /// One malformed row is dropped instead of failing the whole page.
  static List<T> _parseItems<T>(
    Object? rows,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (rows is! List<dynamic>) return <T>[];
    final List<T> out = <T>[];
    for (final Object? row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final T? item = _tryParse(row, parse);
      if (item != null) out.add(item);
    }
    return out;
  }

  static T? _tryParse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) parse,
  ) {
    try {
      return parse(json);
    } on Object {
      return null;
    }
  }
}
