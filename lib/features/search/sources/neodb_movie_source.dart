import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/movie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/neodb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// NeoDB movie catalog. The only movie source here answering in Chinese, with
/// a Douban link on every record — keyless, so no Douban signature to carry.
class NeoDBMovieSource extends SearchSource {
  @override
  String get id => 'neodb_movie';

  @override
  MediaType get outputMediaType => MediaType.movie;

  @override
  DataSource get dataSource => DataSource.neodb;

  @override
  String label(S l) => l.collectionFilterMovies;

  @override
  IconData get icon => Icons.movie_outlined;

  // A missing `query` is a 422 and an empty one a 400, so unlike TMDB this
  // source searches only and never browses.
  @override
  bool get supportsBrowse => false;

  // The catalog search takes no field filters — the search screen's filter bar
  // stays empty for this source.
  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  // `/api/catalog/search` takes no sort parameter either.
  @override
  bool get supportsSortDuringSearch => false;

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'relevance', apiValue: ''),
      ];

  @override
  String searchHint(S l) => l.searchHintMovies;

  @override
  Future<BrowseResult> fetch(
    Ref ref, {
    String? query,
    required Map<String, Object?> filterValues,
    required String sortBy,
    required int page,
  }) async {
    final String? trimmed = query?.trim();
    if (trimmed == null || trimmed.length < kNeoDBMinQueryLength) {
      return const BrowseResult(items: <Object>[], mediaType: MediaType.movie);
    }

    final NeoDBApi api = ref.read(neodbApiProvider);
    final (List<Movie> movies, bool hasMore, int totalPages) =
        await api.searchMovies(query: trimmed, page: page);

    return BrowseResult(
      items: movies,
      mediaType: MediaType.movie,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
