import 'package:core/models/audio_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/douban_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Douban's album catalogue. Albums live under their own subject type with
/// their own search endpoint, unlike the film pool the other Douban sources
/// share. Every request needs the built-in key pair and the host bans a burst,
/// so it searches only.
class DoubanMusicSource extends SearchSource {
  @override
  String get id => 'douban_music';

  @override
  MediaType get outputMediaType => MediaType.audio;

  @override
  DataSource get dataSource => DataSource.douban;

  // The album half of the audio type, so it shares MusicBrainz's label rather
  // than inventing one; the two are one catalogue seen from two providers.
  @override
  String label(S l) => l.searchSourceMusic;

  @override
  IconData get icon => Icons.library_music;

  // The endpoint needs a keyword, and each call spends quota on a ban-prone
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
  String searchHint(S l) => l.searchHintMusic;

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

    final DoubanApi api = ref.read(doubanApiProvider);
    final (List<AudioItem> albums, bool hasMore, int totalPages) =
        await api.searchMusic(query: trimmed, page: page);

    return BrowseResult(
      items: albums,
      mediaType: MediaType.audio,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
