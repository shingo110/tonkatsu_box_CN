import 'package:core/models/data_source.dart';
import 'package:core/models/manga.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/bangumi_api.dart';
import '../../../l10n/app_localizations.dart';
import '../filters/bangumi_manga_meta_tag_filter.dart';
import '../filters/bangumi_rank_filter.dart';
import '../filters/min_rating_filter.dart';
import '../filters/year_filter.dart';
import '../models/search_source.dart';
import '../utils/bangumi_filter_utils.dart';
import '../utils/filter_value_utils.dart';

const int _bangumiPageSize = 20;

/// Bangumi (bgm.tv) manga search — the anime tab's counterpart on the book
/// subject type, and the only manga source here whose titles default to
/// Chinese. Keyless, like the anime tab.
class BangumiMangaSource extends SearchSource {
  @override
  String get id => 'bangumi_manga';

  @override
  MediaType get outputMediaType => MediaType.manga;

  @override
  DataSource get dataSource => DataSource.bangumi;

  @override
  String label(S l) => l.mediaTypeManga;

  @override
  IconData get icon => Icons.auto_stories_outlined;

  @override
  bool get supportsBrowse => true;

  @override
  List<SearchFilter> get filters => <SearchFilter>[
        BangumiMangaMetaTagFilter(),
        YearFilter(),
        MinRatingFilter(),
        BangumiRankFilter(),
      ];

  @override
  List<BrowseSortOption> get sortOptions => const <BrowseSortOption>[
        BrowseSortOption(id: 'relevance', apiValue: 'match'),
        BrowseSortOption(id: 'top_rated', apiValue: 'rank'),
        BrowseSortOption(id: 'popular', apiValue: 'heat'),
      ];

  @override
  bool get supportsSortDuringSearch => true;

  @override
  String searchHint(S l) => l.searchHintManga;

  @override
  Future<BrowseResult> fetch(
    Ref ref, {
    String? query,
    required Map<String, Object?> filterValues,
    required String sortBy,
    required int page,
  }) async {
    final BangumiApi api = ref.read(bangumiApiProvider);

    final Object? rating = filterValues['minRating'];
    final Object? rank = filterValues['maxRank'];

    final (List<Manga> manga, bool hasMore, int totalPages) =
        await api.browseManga(
      query: query,
      metaTags: readFilterStringList(filterValues['metaTags']),
      airDate: bangumiAirDateFor(filterValues['year']),
      rating: rating is num ? <String>[bangumiScoreBound(rating)] : null,
      rank: rank is int ? <String>['>=1', '<=$rank'] : null,
      sort: bangumiSortFor(sortBy, query),
      page: page,
      perPage: _bangumiPageSize,
    );

    return BrowseResult(
      items: manga,
      mediaType: MediaType.manga,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
