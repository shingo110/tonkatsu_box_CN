import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/douban_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Douban's series catalogue. Douban keeps films and series in one search pool
/// and ignores the endpoint's `type` parameter, so [DoubanApi.searchTvShows]
/// splits the rows on this side; a series is one subject with no season split.
class DoubanTvSource extends SearchSource {
  @override
  String get id => 'douban_tv';

  @override
  MediaType get outputMediaType => MediaType.tvShow;

  @override
  DataSource get dataSource => DataSource.douban;

  @override
  String label(S l) => l.collectionFilterTvShows;

  @override
  IconData get icon => Icons.tv_outlined;

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
    if (trimmed == null || trimmed.isEmpty) {
      return const BrowseResult(
        items: <Object>[],
        mediaType: MediaType.tvShow,
      );
    }

    final DoubanApi api = ref.read(doubanApiProvider);
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
