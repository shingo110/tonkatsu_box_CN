/// Bangumi's subject type discriminator. Every request pins it: omitting it
/// mixes books, games and music into one result set.
const int kBangumiAnimeSubjectType = 2;
const int kBangumiBookSubjectType = 1;

/// A book subject covers comics, novels and art books alike, and the meta
/// tag is the only thing that separates them: an unfiltered `type: [1]`
/// search for 海贼王 answered 174 rows of novels and picture books, the same
/// query narrowed by this tag answered 12 comics.
const String kBangumiMangaMetaTag = '漫画';

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
