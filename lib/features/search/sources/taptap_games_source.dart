import 'package:core/models/data_source.dart';
import 'package:core/models/game.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/taptap_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// TapTap's app catalogue — the games source a mainland-China network reaches
/// without a proxy, and the one whose titles, tags and descriptions are Chinese
/// as published rather than translated. IGDB stays the browsable catalogue of
/// the tab; this one answers keywords only, since its endpoint has no browse
/// mode and each call spends a rate-limited quota.
class TapTapGamesSource extends SearchSource {
  @override
  String get id => 'taptap_games';

  @override
  MediaType get outputMediaType => MediaType.game;

  @override
  DataSource get dataSource => DataSource.taptap;

  // One games catalogue seen from two providers, so it shares IGDB's label
  // rather than inventing a second word for the same media type.
  @override
  String label(S l) => l.collectionFilterGames;

  @override
  IconData get icon => Icons.sports_esports_outlined;

  // The endpoint requires a keyword (`kw 或者 can_buy 必填`) and the site has no
  // browse API in reach, so this source searches only.
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
  String searchHint(S l) => l.searchHintGames;

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
      return const BrowseResult(items: <Object>[], mediaType: MediaType.game);
    }

    final TapTapApi api = ref.read(tapTapApiProvider);
    final (List<Game> games, bool hasMore, int totalPages) =
        await api.searchGames(query: trimmed, page: page);

    return BrowseResult(
      items: games,
      mediaType: MediaType.game,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
