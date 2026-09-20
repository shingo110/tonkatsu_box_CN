import 'package:core/api/douban_constants.dart';
import 'package:core/models/book.dart';
import 'package:core/models/movie.dart';
import 'package:core/models/tv_show.dart';
import 'package:dio/dio.dart';

import 'douban_http_client.dart';
import 'douban_types.dart';

/// The signed Frodo book endpoints. A search row already carries title, cover,
/// rating and an "author / year / publisher" line; the by-id and by-ISBN
/// records add the full intro, page count and, for the ISBN path, the ISBN.
class DoubanSearchApi {
  DoubanSearchApi(this._client);

  final DoubanHttpClient _client;

  bool get hasCredentials => _client.hasCredentials;

  /// One page of results with the page count the caller can page through.
  /// `start` is an offset, not a page number.
  Future<(List<Book>, bool, int)> searchBooks({
    required String query,
    int page = 1,
    int perPage = kDoubanSearchCount,
  }) async {
    final int start = (page - 1) * perPage;
    try {
      final Response<dynamic> response = await _client.get(
        kDoubanSearchBookPath,
        queryParameters: <String, dynamic>{
          'q': query,
          'start': start,
          'count': perPage,
        },
      );
      return _parseSearch(response.data, start: start, perPage: perPage);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Douban search failed');
    }
  }

  /// A full record by subject id — the refresh path, since an id is the one
  /// handle a cached row keeps.
  Future<Book?> getBook(String subjectId) async {
    try {
      final Response<dynamic> response =
          await _client.get('$kDoubanBookPath/$subjectId');
      return _parseOne(response.data);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to load the Douban book');
    }
  }

  /// A full record by ISBN-10 or ISBN-13. The response never echoes the ISBN,
  /// so [isbn] comes back from the caller and is stored on the result.
  Future<Book?> getBookByIsbn(String isbn) async {
    final String clean = normalizeDoubanIsbn(isbn);
    try {
      final Response<dynamic> response =
          await _client.get('$kDoubanBookPath/isbn/$clean');
      return _parseOne(response.data, isbn: clean);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to load the Douban book');
    }
  }

  /// One page of films. `/search/movie` answers films and series out of one
  /// mixed pool and ignores its `type` parameter, so the rows are filtered on
  /// `target_type` — a film source must never surface a series.
  Future<(List<Movie>, bool, int)> searchMovies({
    required String query,
    int page = 1,
    int perPage = kDoubanSearchCount,
  }) {
    return _searchSubjects<Movie>(
      query: query,
      page: page,
      perPage: perPage,
      targetType: 'movie',
      parse: Movie.fromDoubanItem,
    );
  }

  /// One page of series — the same mixed endpoint, filtered the other way.
  Future<(List<TvShow>, bool, int)> searchTvShows({
    required String query,
    int page = 1,
    int perPage = kDoubanSearchCount,
  }) {
    return _searchSubjects<TvShow>(
      query: query,
      page: page,
      perPage: perPage,
      targetType: 'tv',
      parse: TvShow.fromDoubanItem,
    );
  }

  /// A full film record. Only a film id resolves here; a series id has to go
  /// through [getTvShow] or Douban answers 996.
  Future<Movie?> getMovie(String subjectId) async {
    try {
      final Response<dynamic> response =
          await _client.get('$kDoubanMoviePath/$subjectId');
      return _parseSubject<Movie>(response.data, Movie.fromDoubanItem);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to load the Douban movie');
    }
  }

  /// A full series record.
  Future<TvShow?> getTvShow(String subjectId) async {
    try {
      final Response<dynamic> response =
          await _client.get('$kDoubanTvPath/$subjectId');
      return _parseSubject<TvShow>(response.data, TvShow.fromDoubanItem);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to load the Douban TV show');
    }
  }

  Future<(List<T>, bool, int)> _searchSubjects<T>({
    required String query,
    required int page,
    required int perPage,
    required String targetType,
    required T Function(Map<String, dynamic> json) parse,
  }) async {
    final int start = (page - 1) * perPage;
    try {
      final Response<dynamic> response = await _client.get(
        kDoubanSearchMoviePath,
        queryParameters: <String, dynamic>{
          'q': query,
          'start': start,
          'count': perPage,
        },
      );
      return _parseSubjectSearch<T>(
        response.data,
        start: start,
        perPage: perPage,
        targetType: targetType,
        parse: parse,
      );
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Douban search failed');
    }
  }

  static (List<T>, bool, int) _parseSubjectSearch<T>(
    Object? data, {
    required int start,
    required int perPage,
    required String targetType,
    required T Function(Map<String, dynamic> json) parse,
  }) {
    if (data is! Map<String, dynamic>) return (<T>[], false, 0);
    final Object? items = data['items'];
    if (items is! List<dynamic>) return (<T>[], false, 0);

    final List<T> kept = <T>[];
    for (final Map<String, dynamic> item
        in items.whereType<Map<String, dynamic>>()) {
      if (item['target_type'] != targetType) continue;
      final Object? target = item['target'];
      if (target is! Map<String, dynamic>) continue;
      try {
        kept.add(parse(target));
      } on FormatException {
        // One malformed row must not cost the caller the whole page.
      }
    }

    final Object? rawTotal = data['total'];
    final int? total = rawTotal is num ? rawTotal.toInt() : null;
    // `total` counts the mixed pool, so paging advances over the rows the host
    // sent rather than over the ones that survived the filter.
    final bool hasMore =
        total != null ? start + items.length < total : items.length >= perPage;
    final int totalPages =
        total != null ? ((total + perPage - 1) ~/ perPage) : 0;
    return (kept, hasMore, totalPages);
  }

  static T? _parseSubject<T>(
    Object? data,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (data is! Map<String, dynamic>) return null;
    // A missing subject answers with an error object rather than a 404.
    if (data['title'] == null && data['id'] == null) return null;
    try {
      return parse(data);
    } on FormatException {
      return null;
    }
  }

  static (List<Book>, bool, int) _parseSearch(
    Object? data, {
    required int start,
    required int perPage,
  }) {
    if (data is! Map<String, dynamic>) {
      return (const <Book>[], false, 0);
    }
    final Object? items = data['items'];
    if (items is! List<dynamic>) {
      return (const <Book>[], false, 0);
    }

    final List<Book> books = <Book>[];
    for (final Map<String, dynamic> item
        in items.whereType<Map<String, dynamic>>()) {
      try {
        books.add(Book.fromDoubanItem(item));
      } on FormatException {
        // One malformed row must not cost the caller the whole page.
      }
    }

    final Object? rawTotal = data['total'];
    final int? total = rawTotal is num ? rawTotal.toInt() : null;
    // `total` counts every match, so it alone decides whether another page
    // exists; without it, a full page is the only signal available.
    final bool hasMore =
        total != null ? start + books.length < total : books.length >= perPage;
    final int totalPages = total != null ? ((total + perPage - 1) ~/ perPage) : 0;
    return (books, hasMore, totalPages);
  }

  static Book? _parseOne(Object? data, {String? isbn}) {
    if (data is! Map<String, dynamic>) return null;
    // A missing subject answers with an error object rather than a 404.
    if (data['title'] == null && data['id'] == null) return null;
    try {
      return Book.fromDoubanItem(data, isbn: isbn);
    } on FormatException {
      return null;
    }
  }
}
