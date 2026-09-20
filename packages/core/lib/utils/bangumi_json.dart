/// Parsing helpers for Bangumi (bgm.tv) subjects. Anime and manga are two
/// subject types on one endpoint and answer with the same field set, so the
/// two mappings share these helpers rather than each keeping a copy.
///
/// The two differ in vocabulary, not shape: `platform` is a broadcast format
/// for anime but the literal string 漫画 for a book subject, the studio
/// infobox key is 动画制作 against 作者 for authorship, and only a manga's
/// `meta_tags` carry a serialisation state (连载中 / 已完结). Those splits are
/// the arguments below, not separate parsers.
library;

/// Numeric subject id, and the cache key. Bangumi mints it as a number.
int bangumiSubjectId(Map<String, dynamic> json) {
  final Object? raw = json['id'];
  if (raw is num) return raw.toInt();
  final int? parsed = raw is String ? int.tryParse(raw.trim()) : null;
  if (parsed == null) {
    throw const FormatException('Bangumi subject without a numeric id');
  }
  return parsed;
}

/// Display title, Chinese first. Bangumi keeps the original in `name` and the
/// Chinese name in `name_cn`, and only the latter is worth showing in this app.
String? bangumiSubjectTitle(Map<String, dynamic> json) =>
    _nonEmpty(json['name_cn']) ?? _nonEmpty(json['name']);

/// Original title as Bangumi spells it — romanised for most Japanese works.
String? bangumiSubjectOriginalTitle(Map<String, dynamic> json) =>
    _nonEmpty(json['name']);

/// Synopsis, in Chinese.
String? bangumiSubjectSummary(Map<String, dynamic> json) =>
    _nonEmpty(json['summary']);

/// Poster. `images.large` is the full-size cover; `image` is the same URL.
String? bangumiCoverUrl(Map<String, dynamic> json) {
  final Object? images = json['images'];
  if (images is Map<String, dynamic>) {
    final String? large = _nonEmpty(images['large']);
    if (large != null) return large;
  }
  return _nonEmpty(json['image']);
}

String? bangumiCoverUrlMedium(Map<String, dynamic> json) {
  final Object? images = json['images'];
  if (images is Map<String, dynamic>) {
    return _nonEmpty(images['common']);
  }
  return null;
}

/// Community score on the app's 0–100 scale. Bangumi rates 0–10, so the same
/// rule as [Anime.fromBangumi] applies here: multiply, never use raw.
int? bangumiAverageScore(Map<String, dynamic> json) {
  final Object? rating = json['rating'];
  if (rating is! Map<String, dynamic>) return null;
  final Object? score = rating['score'];
  if (score is! num || score <= 0) return null;
  return (score * 10).round();
}

/// Calendar rows carry `air_date`; search and subject rows carry `date`.
String? bangumiSubjectDate(Map<String, dynamic> json) =>
    _nonEmpty(json['date']) ?? _nonEmpty(json['air_date']);

/// Bangumi dates are `YYYY-MM-DD`; partial values (`2024-04`) leave the
/// trailing parts null.
int? bangumiDatePart(String? date, int index) {
  if (date == null) return null;
  final List<String> parts = date.split('-');
  return parts.length > index ? int.tryParse(parts[index]) : null;
}

/// A count that is present or null. Bangumi answers 0 for "not filled in",
/// which must not be stored as a real zero.
int? bangumiCount(Object? raw) {
  if (raw is! num) return null;
  final int value = raw.toInt();
  return value > 0 ? value : null;
}

/// Bangumi carries no airing flag, so only the case needing no inference is
/// derived: a start date still in the future.
String? bangumiAiringStatus(String? date) {
  final DateTime? start = date == null ? null : DateTime.tryParse(date);
  if (start == null) return null;
  return start.isAfter(DateTime.now()) ? 'NOT_YET_RELEASED' : null;
}

/// Serialisation state, which only a book subject states outright. Bangumi
/// exposes it as a meta tag instead of a field, and the vocabulary is fixed.
String? bangumiMangaStatus(String? date, Object? metaTags) {
  final String? future = bangumiAiringStatus(date);
  if (future != null) return future;
  if (metaTags is! List<dynamic>) return null;
  for (final Object? entry in metaTags) {
    final String? tag = _nonEmpty(entry);
    if (tag == '连载中') return 'RELEASING';
    if (tag == '已完结') return 'FINISHED';
  }
  return null;
}

/// Bangumi meta tags, which are a closed vocabulary: origin, adaptation
/// source, audience and serialisation state.
List<String> bangumiMetaTags(Object? raw) {
  if (raw is! List<dynamic>) return const <String>[];
  final List<String> out = <String>[];
  for (final Object? entry in raw) {
    final String? tag = _nonEmpty(entry);
    if (tag != null) out.add(tag);
  }
  return out;
}

/// Bangumi tags are community votes ordered by count, so the head of the list
/// carries the meaning and the tail is one-off spelling variants.
const int _maxTags = 12;

List<String>? bangumiTagNames(Object? raw) {
  if (raw is! List<dynamic>) return null;
  final List<String> out = <String>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, dynamic>) continue;
    final String? name = _nonEmpty(entry['name']);
    if (name != null) out.add(name);
    if (out.length >= _maxTags) break;
  }
  return out.isEmpty ? null : out;
}

/// Flattens Bangumi's `infobox` list into a `key -> raw value` map.
Map<String, dynamic> bangumiInfobox(Object? raw) {
  if (raw is! List<dynamic>) return const <String, dynamic>{};
  final Map<String, dynamic> out = <String, dynamic>{};
  for (final Object? entry in raw) {
    if (entry is! Map<String, dynamic>) continue;
    final Object? key = entry['key'];
    if (key is String && key.isNotEmpty) out[key] = entry['value'];
  }
  return out;
}

/// An infobox value is a bare string or a list of `{'v': ...}` maps; either
/// can pack several names into one ` / ` separated string.
List<String> bangumiInfoboxValues(Object? raw) {
  final List<Object?> entries = switch (raw) {
    final String value => <Object?>[value],
    final List<dynamic> list => list,
    _ => const <Object?>[],
  };
  final List<String> out = <String>[];
  for (final Object? entry in entries) {
    final String? value = switch (entry) {
      final String text => text,
      final Map<String, dynamic> map => _nonEmpty(map['v']),
      _ => null,
    };
    if (value == null) continue;
    for (final String part in value.split(' / ')) {
      final String trimmed = part.trim();
      if (trimmed.isNotEmpty && !out.contains(trimmed)) out.add(trimmed);
    }
  }
  return out;
}

/// The studio, from the dedicated key first and the production committee
/// second. Bangumi may list several, joined by ` / `.
List<String>? bangumiAnimeStudios(Map<String, dynamic> infobox) {
  for (final String key in const <String>['动画制作', '製作', '制作']) {
    final List<String> names = bangumiInfoboxValues(infobox[key]);
    if (names.isNotEmpty) return names;
  }
  return null;
}

/// Authorship. A book subject credits 作者, and a drawn work splits the credit
/// into 作画 when the writer and the artist differ.
List<String>? bangumiMangaAuthors(Map<String, dynamic> infobox) {
  for (final String key in const <String>['作者', '作画', '原作']) {
    final List<String> names = bangumiInfoboxValues(infobox[key]);
    if (names.isNotEmpty) return names;
  }
  return null;
}

/// Maps Bangumi's `platform` onto the AniList format vocabulary. The Chinese
/// literals are the API's own values, not prose.
String? bangumiAnimeFormat(String? platform) => switch (platform) {
      'TV' => 'TV',
      'WEB' || '动态漫画' => 'ONA',
      'OVA' || 'OAD' => 'OVA',
      '剧场版' || '剧场版动画' => 'MOVIE',
      _ => null,
    };

/// A book subject's `platform` names the medium. The manga source filters on
/// the 漫画 meta tag, so anything else here is a mis-filed row.
String? bangumiMangaFormat(String? platform) => switch (platform) {
      '漫画' => 'MANGA',
      _ => null,
    };

String? _nonEmpty(Object? raw) {
  if (raw is! String) return null;
  final String value = raw.trim();
  return value.isEmpty ? null : value;
}
