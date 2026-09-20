import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/movie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/douban_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Douban's film catalogue. The deepest Chinese metadata of any source here,
/// but every request needs a user-supplied key and secret pair and the host
/// bans a burst, so it ranks behind the keyless NeoDB.
class DoubanMovieSource extends SearchSource {
  @override
  String get id => 'douban_movie';

  @override
  MediaType get outputMediaType => MediaType.movie;

  @override
  DataSource get dataSource => DataSource.douban;

  @override
  String label(S l) => l.collectionFilterMovies;

  @override
  IconData get icon => Icons.movie_outlined;

  // The endpoint needs a keyword and each call costs quota on a ban-prone
  // host, so this source searches only and never browses.
  @override
  bool get supportsBrowse => false;

  // The search endpoint takes no field filters.
  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  // It takes no sort parameter either.
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
    if (trimmed == null || trimmed.isEmpty) {
      return const BrowseResult(items: <Object>[], mediaType: MediaType.movie);
    }

    final DoubanApi api = ref.read(doubanApiProvider);
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
