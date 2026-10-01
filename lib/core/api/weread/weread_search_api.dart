import 'package:core/models/book.dart';
import 'package:dio/dio.dart';

import 'weread_http_client.dart';
import 'weread_types.dart';

/// WeRead book search. Keyless, and every search row is already the whole
/// record, so no call here re-fetches by id.
class WeReadSearchApi {
  WeReadSearchApi(this._client);

  final WeReadHttpClient _client;

  /// `maxIdx` is an offset, so page `n` starts at `(n - 1) * count`.
  Future<(List<Book>, bool hasMore, int totalPages)> searchBooks({
    required String query,
    int page = 1,
    int perPage = kWeReadPageSize,
  }) async {
    final int count = perPage.clamp(1, kWeReadMaxCount);
    final int maxIdx = (page - 1) * count;
    try {
      final Response<dynamic> resp = await _client.get(
        kWeReadSearchPath,
        queryParameters: <String, dynamic>{
          'keyword': query,
          'maxIdx': maxIdx,
          'count': count,
        },
      );
      final List<Book> books = _parseBooks(resp.data);

      // `totalCount` did jump between requests for some queries, so it only
      // shortens the run — it can never extend it, and an empty page is still
      // the authoritative terminator. Dropping the old 400-offset ceiling lets
      // searches with more than 400 results page all the way through.
      final int? total = _parseTotal(resp.data);
      final bool hasMore = total != null
          ? books.isNotEmpty && maxIdx + count < total
          : books.isNotEmpty;

      return (books, hasMore, hasMore ? page + 1 : page);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search WeRead');
    }
  }

  /// Row lookup for the refresh path. WeRead publishes no by-id endpoint, but
  /// an exact title search returns the wanted record — `三体全集（全三册）`
  /// put its own bookId first — so the title is searched again and the row
  /// matched on bookId.
  Future<Book?> findByNativeId({
    required String title,
    required String nativeId,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final (List<Book> books, _, _) = await searchBooks(query: trimmed);
    for (final Book book in books) {
      if (book.nativeId == nativeId) return book;
    }
    return null;
  }

  /// A body that is not an object means "no keyword": WeRead answers 200 with
  /// an empty payload rather than an error, which reads as an empty page.
  static List<Book> _parseBooks(Object? data) {
    if (data is! Map<String, dynamic>) return const <Book>[];
    final Object? rows = data['books'];
    if (rows is! List<dynamic>) return const <Book>[];
    final List<Book> out = <Book>[];
    for (final Object? row in rows) {
      if (row is! Map<String, dynamic>) continue;
      try {
        out.add(Book.fromWeReadItem(row));
      } on Object {
        // One malformed row is dropped instead of failing the whole page.
      }
    }
    return out;
  }

  /// WeRead's total is named `totalCount` (older deployments answered `total`);
  /// either is accepted and a missing one leaves pagination to empty pages.
  static int? _parseTotal(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    final Object? raw = data['totalCount'] ?? data['total'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
