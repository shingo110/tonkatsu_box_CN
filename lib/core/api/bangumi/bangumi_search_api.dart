import 'package:dio/dio.dart';

import 'bangumi_http_client.dart';
import 'bangumi_types.dart';

/// Bangumi v0 subject search. Keyless; 30 back-to-back searches all answered
/// 200, so unlike AniList this one needs no pacing.
class BangumiSearchApi {
  BangumiSearchApi(this._client);

  final BangumiHttpClient _client;

  /// Search and browse share one endpoint: with an empty keyword the filter
  /// alone drives the result set, which is how the browse tab works.
  Future<(List<T>, bool hasMore, int totalPages)> searchSubjects<T>({
    required T Function(Map<String, dynamic>) parse,
    int subjectType = kBangumiAnimeSubjectType,
    String? query,
    List<String>? tags,
    List<String>? metaTags,
    List<String>? airDate,
    List<String>? rating,
    List<String>? rank,
    String sort = kBangumiSortMatch,
    int page = 1,
    int perPage = 20,
  }) async {
    final int offset = (page - 1) * perPage;
    final Map<String, dynamic> filter = <String, dynamic>{
      'type': <int>[subjectType],
      if (tags != null && tags.isNotEmpty) 'tag': tags,
      if (metaTags != null && metaTags.isNotEmpty) 'meta_tags': metaTags,
      if (airDate != null && airDate.isNotEmpty) 'air_date': airDate,
      if (rating != null && rating.isNotEmpty) 'rating': rating,
      if (rank != null && rank.isNotEmpty) 'rank': rank,
      // Adult entries are opt-in on Bangumi; a general search stays sfw.
      'nsfw': false,
    };

    try {
      final Response<dynamic> resp = await _client.post(
        'v0/search/subjects',
        queryParameters: <String, dynamic>{'limit': perPage, 'offset': offset},
        body: <String, dynamic>{
          'keyword': query ?? '',
          'sort': sort,
          'filter': filter,
        },
      );
      final Map<String, dynamic> data =
          (resp.data as Map<String, dynamic>?) ?? <String, dynamic>{};
      final List<T> items = _parseSubjects<T>(data['data'], parse);

      final int total = (data['total'] as num?)?.toInt() ?? items.length;
      final bool hasMore = offset + items.length < total;
      final int totalPages = perPage > 0 ? (total / perPage).ceil() : 1;

      return (items, hasMore, totalPages < 1 ? 1 : totalPages);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search Bangumi');
    }
  }

  /// Full subject by id. Search rows already carry nearly every field, so this
  /// serves the refresh path and the wider detail payload.
  Future<T?> getSubject<T>(
    int id,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final Response<dynamic> resp = await _client.get('v0/subjects/$id');
      final Object? data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      return parse(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _client.handleDioException(e, 'Failed to load the Bangumi subject');
    }
  }

  /// One malformed row is dropped instead of failing the whole page.
  static List<T> _parseSubjects<T>(
    Object? rows,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (rows is! List<dynamic>) return <T>[];
    final List<T> out = <T>[];
    for (final Object? row in rows) {
      if (row is! Map<String, dynamic>) continue;
      try {
        out.add(parse(row));
      } on Object {
        continue;
      }
    }
    return out;
  }
}
