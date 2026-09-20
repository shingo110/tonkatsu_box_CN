import 'package:core/models/book.dart';
import 'package:core/models/movie.dart';
import 'package:core/models/tv_show.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'neodb/neodb_http_client.dart';
import 'neodb/neodb_search_api.dart';
import 'neodb/neodb_types.dart';

export 'neodb/neodb_types.dart';

final Provider<NeoDBApi> neodbApiProvider =
    Provider<NeoDBApi>((Ref ref) => NeoDBApi());

/// NeoDB (neodb.social) REST facade — a federated Chinese-language catalog
/// whose `external_resources` carry the matching Douban / IMDb links, which is
/// what makes it usable here without touching Douban directly.
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
      _search.search<Book>(
        query: query,
        category: kNeoDBBookCategory,
        parse: Book.fromNeoDBItem,
        page: page,
      );

  Future<(List<Movie>, bool hasMore, int totalPages)> searchMovies({
    required String query,
    int page = 1,
  }) =>
      _search.search<Movie>(
        query: query,
        category: kNeoDBMovieCategory,
        parse: Movie.fromNeoDBItem,
        page: page,
      );

  Future<(List<TvShow>, bool hasMore, int totalPages)> searchTvShows({
    required String query,
    int page = 1,
  }) =>
      _search.search<TvShow>(
        query: query,
        category: kNeoDBTvCategory,
        parse: TvShow.fromNeoDBItem,
        page: page,
      );

  /// [uuid] is the NeoDB uuid, not the numeric model id.
  Future<Book?> getBookById(String uuid) => _search.getItem<Book>(
        uuid,
        category: kNeoDBBookCategory,
        parse: Book.fromNeoDBItem,
      );

  Future<Movie?> getMovieById(String uuid) => _search.getItem<Movie>(
        uuid,
        category: kNeoDBMovieCategory,
        parse: Movie.fromNeoDBItem,
      );

  /// Search files TV as seasons, so every stored id addresses one — the
  /// `season` segment is not a guess but the shape this catalogue returns.
  Future<TvShow?> getTvShowById(String uuid) => _search.getItem<TvShow>(
        uuid,
        category: kNeoDBTvCategory,
        segment: 'season',
        parse: TvShow.fromNeoDBItem,
      );

  void dispose() => _client.dispose();
}
