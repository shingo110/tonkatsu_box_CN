import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/neodb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// NeoDB TV catalog. The catalogue files TV as seasons, so every result is a
/// season and its title carries the number ("甄嬛传 第 1 季") — collecting one
/// season is the unit this source offers.
class NeoDBTvSource extends SearchSource {
  @override
  String get id => 'neodb_tv';

  @override
  MediaType get outputMediaType => MediaType.tvShow;

  @override
  DataSource get dataSource => DataSource.neodb;

  @override
  String label(S l) => l.collectionFilterTvShows;

  @override
  IconData get icon => Icons.tv_outlined;

  // A missing `query` is a 422 and an empty one a 400, so unlike TMDB this
  // source searches only and never browses.
  @override
  bool get supportsBrowse => false;

  @override
  List<SearchFilter> get filters => const <SearchFilter>[];

  @override
  bool get supportsSortDuringSearch => false;

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'relevance', apiValue: ''),
      ];

  @override
  String searchHint(S l) => l.searchHintTv;

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
      return const BrowseResult(items: <Object>[], mediaType: MediaType.tvShow);
    }

    final NeoDBApi api = ref.read(neodbApiProvider);
    final (List<TvShow> shows, bool hasMore, int totalPages) =
        await api.searchTvShows(query: trimmed, page: page);

    return BrowseResult(
      items: shows,
      mediaType: MediaType.tvShow,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
