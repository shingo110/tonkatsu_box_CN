/// WeRead (weread.qq.com) search contract.
///
/// There is one keyless door: the public search endpoint. `web/book/info`
/// answers `errCode -2010` ("user does not exist") for anyone without a
/// signed-in cookie, so a search row is the only complete record this source
/// ever sees, and nothing here fetches by id.
const String kWeReadSearchPath = 'web/search/global';

/// `count` is honoured exactly up to this ceiling — larger values are clamped
/// rather than rejected.
const int kWeReadMaxCount = 50;

/// Page size to ask for; `maxIdx` is a plain offset, not a page number.
const int kWeReadPageSize = 20;

/// WeRead answers any non-empty keyword, a single character included. An empty
/// keyword returns no books at all, so this source searches only.
const int kWeReadMinQueryLength = 1;

/// Result sets are fuzzy and effectively endless, and `totalCount` proved
/// untrustworthy (59 for the first two pages, 10087 from the third) while
/// `hasMore` stays pinned at 1 — so paging ends on an empty page. This ceiling
/// only keeps a runaway scroll bounded.
const int kWeReadMaxOffset = 400;

/// Error from the WeRead API. [detail] is a redacted, copyable debug string
/// (request + status + body) consumed by `extractApiError`.
class WeReadApiException implements Exception {
  const WeReadApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'WeReadApiException: $message (status: $statusCode)';
}
