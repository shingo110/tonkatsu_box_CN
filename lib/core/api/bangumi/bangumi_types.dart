/// Bangumi's subject type discriminator. Every request pins it: omitting it
/// mixes books, games and music into an anime search.
const int kBangumiAnimeSubjectType = 2;

/// Values `/v0/search/subjects` accepts for `sort`; anything else is a 400.
/// `match` scores against the keyword and is meaningless without one.
const String kBangumiSortMatch = 'match';
const String kBangumiSortHeat = 'heat';
const String kBangumiSortRank = 'rank';

/// Error from the Bangumi API. [detail] is a redacted, copyable debug
/// string (request + status + body) consumed by `extractApiError`.
class BangumiApiException implements Exception {
  const BangumiApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'BangumiApiException: $message (status: $statusCode)';
}
