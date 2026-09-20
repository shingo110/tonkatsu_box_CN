import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/weread_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// WeRead (weread.qq.com) — the Chinese e-book store. It is the only source
/// here that carries web novels and digital-first editions, which no ISBN
/// catalogue lists. Keyless.
class WeReadBookSource extends SearchSource {
  @override
  String get id => 'weread';

  @override
  MediaType get outputMediaType => MediaType.book;

  @override
  DataSource get dataSource => DataSource.weread;

  @override
  String label(S l) => l.collectionFilterBooks;

  @override
  IconData get icon => Icons.local_library;

  // An empty keyword answers with no books at all, so this source searches
  // only and never browses.
  @override
  bool get supportsBrowse => false;

  // `/web/search/global` takes no field filters.
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
    if (trimmed == null || trimmed.length < kWeReadMinQueryLength) {
      return const BrowseResult(items: <Object>[], mediaType: MediaType.book);
    }

    final WeReadApi api = ref.read(wereadApiProvider);
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
