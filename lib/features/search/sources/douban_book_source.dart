import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/douban_api.dart';
import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Douban (book.douban.com) — the Chinese book catalogue. Reached through its
/// signed Frodo API, so it asks the user for a key and a secret pair.
class DoubanBookSource extends SearchSource {
  @override
  String get id => 'douban';

  @override
  MediaType get outputMediaType => MediaType.book;

  @override
  DataSource get dataSource => DataSource.douban;

  @override
  String label(S l) => l.collectionFilterBooks;

  @override
  IconData get icon => Icons.menu_book;

  // A missing keyword is not a search, so unlike Bangumi this source searches
  // only and never browses.
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
    if (trimmed == null || trimmed.isEmpty) {
      return const BrowseResult(items: <Object>[], mediaType: MediaType.book);
    }

    final DoubanApi api = ref.read(doubanApiProvider);

    // An ISBN takes the direct path: one call answers with the whole record,
    // and a keyword search would only spend a call on a ban-prone host.
    if (isDoubanIsbn(trimmed)) {
      final Book? book = await api.getBookByIsbn(trimmed);
      if (book == null) {
        return const BrowseResult(items: <Object>[], mediaType: MediaType.book);
      }
      return BrowseResult(
        items: <Book>[book],
        mediaType: MediaType.book,
        currentPage: 1,
      );
    }

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
