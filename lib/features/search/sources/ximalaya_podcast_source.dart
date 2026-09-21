import 'package:core/models/audio_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/ximalaya_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Ximalaya's album catalogue — the podcast half of the audio type, in Chinese,
/// on a host a mainland network reaches without a proxy. Podcast Index stays
/// the open RSS catalogue of the tab; this one answers keywords only, since its
/// endpoint has no browse mode and its album detail door is closed.
class XimalayaPodcastSource extends SearchSource {
  @override
  String get id => 'ximalaya_podcast';

  @override
  MediaType get outputMediaType => MediaType.audio;

  @override
  DataSource get dataSource => DataSource.ximalaya;

  // One podcast catalogue seen from two providers, so it shares Podcast
  // Index's label rather than inventing a second word for the same media type.
  @override
  String label(S l) => l.searchSourcePodcasts;

  @override
  IconData get icon => Icons.radio_outlined;

  // An empty keyword answers `no such search word` and the album detail
  // endpoint answers a blacklist page, so this source searches only.
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
  String searchHint(S l) => l.searchHintPodcasts;

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
      return const BrowseResult(items: <Object>[], mediaType: MediaType.audio);
    }

    final XimalayaApi api = ref.read(ximalayaApiProvider);
    final (List<AudioItem> albums, bool hasMore, int totalPages) =
        await api.searchPodcasts(query: trimmed, page: page);

    return BrowseResult(
      items: albums,
      mediaType: MediaType.audio,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
