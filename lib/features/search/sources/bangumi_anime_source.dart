import 'package:core/models/anime.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/bangumi_api.dart';
import '../../../l10n/app_localizations.dart';
import '../filters/bangumi_meta_tag_filter.dart';
import '../filters/bangumi_rank_filter.dart';
import '../filters/min_rating_filter.dart';
import '../filters/year_filter.dart';
import '../models/search_source.dart';
import '../utils/filter_value_utils.dart';

const int _bangumiPageSize = 20;

/// Bangumi (bgm.tv) anime search. The only anime source here whose titles
/// default to Chinese, and the only one carrying Chinese community tags.
class BangumiAnimeSource extends SearchSource {
  @override
  String get id => 'bangumi_anime';

  @override
  MediaType get outputMediaType => MediaType.anime;

  @override
  DataSource get dataSource => DataSource.bangumi;

  @override
  String label(S l) => l.mediaTypeAnime;

  @override
  IconData get icon => Icons.live_tv_outlined;

  @override
  bool get supportsBrowse => true;

  @override
  List<SearchFilter> get filters => <SearchFilter>[
        BangumiMetaTagFilter(),
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
  String searchHint(S l) => l.searchHintAnime;

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

    final (List<Anime> anime, bool hasMore, int totalPages) =
        await api.browseAnime(
      query: query,
      metaTags: readFilterStringList(filterValues['metaTags']),
      airDate: _airDateFor(filterValues['year']),
      rating: rating is num ? <String>[_scoreBound(rating)] : null,
      rank: rank is int ? <String>['>=1', '<=$rank'] : null,
      sort: _sortFor(sortBy, query),
      page: page,
      perPage: _bangumiPageSize,
    );

    return BrowseResult(
      items: anime,
      mediaType: MediaType.anime,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }

  /// `YearFilter` stores either a year or a `(start, end)` decade tuple;
  /// Bangumi wants them as an inclusive-start / exclusive-end date pair.
  static List<String>? _airDateFor(Object? value) {
    int? start;
    int? end;
    if (value is int) {
      start = value;
      end = value;
    } else if (value is (int, int)) {
      start = value.$1;
      end = value.$2;
    }
    if (start == null || end == null) return null;
    return <String>['>=$start-01-01', '<${end + 1}-01-01'];
  }

  /// `MinRatingFilter` stores doubles; Bangumi expects `>=8`, not `>=8.0`.
  static String _scoreBound(num value) =>
      value == value.roundToDouble() ? '>=${value.round()}' : '>=$value';

  /// `match` scores the result set against the keyword, so a keyword-less
  /// browse falls back to the community ranking instead.
  static String _sortFor(String apiValue, String? query) {
    final bool hasQuery = query != null && query.trim().isNotEmpty;
    if (apiValue == 'match' && !hasQuery) return 'rank';
    return apiValue;
  }
}
