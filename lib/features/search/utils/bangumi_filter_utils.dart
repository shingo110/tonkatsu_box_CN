/// Filter translation shared by the two Bangumi sources. Bangumi takes
/// `air_date` and `rating` as bound pairs and `sort` as a bare keyword, so the
/// anime tab and the manga tab need the same three conversions; keeping one
/// copy means the two cannot drift apart.
library;

/// `YearFilter` stores either a year or a `(start, end)` decade tuple;
/// Bangumi wants them as an inclusive-start / exclusive-end date pair.
List<String>? bangumiAirDateFor(Object? value) {
  int? start;
  int? end;
  if (value is int) {
    start = value;
    end = value;
  } else if (value is (int, int)) {
    start = value.$1;
    end = value.$2;
  }
  if (start == null || end == null) return null;
  return <String>['>=$start-01-01', '<${end + 1}-01-01'];
}

/// `MinRatingFilter` stores doubles; Bangumi expects `>=8`, not `>=8.0`.
String bangumiScoreBound(num value) =>
    value == value.roundToDouble() ? '>=${value.round()}' : '>=$value';

/// `match` scores the result set against the keyword, so a keyword-less
/// browse falls back to the community ranking instead.
String bangumiSortFor(String apiValue, String? query) {
  final bool hasQuery = query != null && query.trim().isNotEmpty;
  return (apiValue == 'match' && !hasQuery) ? 'rank' : apiValue;
}
