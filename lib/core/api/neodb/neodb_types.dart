/// NeoDB catalog categories. The search endpoint and the detail path share one
/// token (`/api/catalog/search?category=book` → `/api/book/{uuid}`), so these
/// constants drive both calls.
const String kNeoDBBookCategory = 'book';

const String kNeoDBMovieCategory = 'movie';

/// TV items live under `tv`, but search only ever returns `TVSeason` records —
/// their detail path adds a `season` segment (`/api/tv/season/{uuid}`).
const String kNeoDBTvCategory = 'tv';

/// Shortest query worth sending: NeoDB answers a one-character keyword with
/// 400, so every source stops below this instead of spending a request.
const int kNeoDBMinQueryLength = 2;

/// Error from the NeoDB API. [detail] is a redacted, copyable debug
/// string (request + status + body) consumed by `extractApiError`.
class NeoDBApiException implements Exception {
  const NeoDBApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'NeoDBApiException: $message (status: $statusCode)';
}
