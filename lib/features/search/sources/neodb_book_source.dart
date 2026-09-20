import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/neodb_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

const int _neodbMinQuery = 2;

/// NeoDB book catalog. The only Chinese-language book source here: titles,
/// descriptions and tags all arrive in Chinese, and `external_resources`
/// points at the matching Douban entry. Keyless.
class NeoDBBookSource extends SearchSource {
  @override
  String get id => 'neodb';

  @override
  MediaType get outputMediaType => MediaType.book;

  @override
  DataSource get dataSource => DataSource.neodb;

  @override
  String label(S l) => l.collectionFilterBooks;

  @override
  IconData get icon => Icons.auto_stories;

  // A missing `query` is a 422 and an empty one a 400, so unlike Bangumi this
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
  String searchHint(S l) => l.searchHintBooks;

  @override
  Future<BrowseResult> fetch(
    Ref ref, {
    String? query,
    required Map<String, Object?> filterValues,
    required String sortBy,
    required int page,
  }) async {
    final String? trimmed = query?.trim();
    if (trimmed == null || trimmed.length < _neodbMinQuery) {
      return const BrowseResult(items: <Object>[], mediaType: MediaType.book);
    }

    final NeoDBApi api = ref.read(neodbApiProvider);
    final (List<Book> books, bool hasMore, int totalPages) =
        await api.searchBooks(query: trimmed, page: page);

    return BrowseResult(
      items: books,
      mediaType: MediaType.book,
      hasMore: hasMore,
      totalPages: totalPages,
      currentPage: page,
    );
  }
}
