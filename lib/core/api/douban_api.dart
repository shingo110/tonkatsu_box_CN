import 'package:core/models/book.dart';
import 'package:core/models/movie.dart';
import 'package:core/models/tv_show.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/constants/platform_features.dart';
import '../services/api_key_initializer.dart';
import 'douban/douban_http_client.dart';
import 'douban/douban_search_api.dart';
import 'douban/douban_types.dart';

export 'douban/douban_types.dart'
    show DoubanApiException, isDoubanIsbn, normalizeDoubanIsbn;

/// The pair comes from Settings; without one the client refuses a request
/// before it leaves, so a missing key reads as "not configured" rather than
/// as a failure.
final Provider<DoubanApi> doubanApiProvider = Provider<DoubanApi>((Ref ref) {
  final DoubanApi api = DoubanApi();
  final ApiKeys keys = ref.read(apiKeysProvider);
  final String? key = keys.doubanApiKey;
  final String? secret = keys.doubanApiSecret;
  if (key != null && key.isNotEmpty && secret != null && secret.isNotEmpty) {
    api.setCredentials(key, secret);
  }
  ref.onDispose(api.dispose);
  return api;
});

/// Douban's signed Frodo API. Two backends behind one façade: a keyword goes
/// to `/search/book`, a query that is an ISBN goes straight to `/book/isbn/`.
class DoubanApi {
  DoubanApi({Dio? dio, DateTime Function()? now})
      : _client = DoubanHttpClient(dio: dio, now: now);

  final DoubanHttpClient _client;
  late final DoubanSearchApi _search = DoubanSearchApi(_client);

  void setCredentials(String apiKey, String secret) =>
      _client.setCredentials(apiKey, secret);

  void clearCredentials() => _client.clearCredentials();

  bool get hasCredentials => _client.hasCredentials;

  /// A native build with no pair has nothing to sign with, so the call is
  /// skipped rather than sent unsigned; the browser is exempt because the
  /// selfhost proxy holds the pair and signs there.
  bool get _canRequest => _client.hasCredentials || kIsWebBuild;

  /// One page of search results, whether more follow, and the page count.
  Future<(List<Book>, bool, int)> searchBooks({
    required String query,
    int page = 1,
  }) {
    if (!_canRequest) {
      return Future<(List<Book>, bool, int)>.value(
        (const <Book>[], false, 0),
      );
    }
    return _search.searchBooks(query: query, page: page);
  }

  /// The full record behind a cached row.
  Future<Book?> getBook(String subjectId) =>
      _canRequest ? _search.getBook(subjectId) : Future<Book?>.value();

  /// The full record an ISBN points at.
  Future<Book?> getBookByIsbn(String isbn) => _canRequest
      ? _search.getBookByIsbn(isbn)
      : Future<Book?>.value();

  /// One page of films, whether more follow, and the page count.
  Future<(List<Movie>, bool, int)> searchMovies({
    required String query,
    int page = 1,
  }) {
    if (!_canRequest) {
      return Future<(List<Movie>, bool, int)>.value(
        (const <Movie>[], false, 0),
      );
    }
    return _search.searchMovies(query: query, page: page);
  }

  /// One page of series. Douban keeps films and series in one search pool, so
  /// the split happens on this side.
  Future<(List<TvShow>, bool, int)> searchTvShows({
    required String query,
    int page = 1,
  }) {
    if (!_canRequest) {
      return Future<(List<TvShow>, bool, int)>.value(
        (const <TvShow>[], false, 0),
      );
    }
    return _search.searchTvShows(query: query, page: page);
  }

  /// The full record behind a cached film row.
  Future<Movie?> getMovie(String subjectId) =>
      _canRequest ? _search.getMovie(subjectId) : Future<Movie?>.value();

  /// The full record behind a cached series row.
  Future<TvShow?> getTvShow(String subjectId) =>
      _canRequest ? _search.getTvShow(subjectId) : Future<TvShow?>.value();

  /// True when the stored pair signs a request Frodo accepts.
  Future<bool> validateCredentials() async {
    if (!_client.hasCredentials) return false;
    try {
      await _search.searchBooks(query: '三体', perPage: 1);
      return true;
    } on DoubanApiException {
      return false;
    }
  }

  void dispose() => _client.dispose();
}
