import 'html_text.dart';

/// Parsing helpers for NeoDB items (neodb.social). A `/api/catalog/search`
/// row and the matching `/api/{category}/{uuid}` response carry the same
/// field set, so one helper set serves the book, movie and TV mappings.

/// Item title. `localized_title` wins because NeoDB's `display_title` is the
/// English rendering for movie / TV records — only books get a Chinese one.
String? neodbItemTitle(Map<String, dynamic> json) {
  final String? localized = neodbChineseText(json['localized_title']);
  if (localized != null) return localized;
  return _nonEmpty(json['display_title']) ?? _nonEmpty(json['title']);
}

/// Original-language title. NeoDB leaves `orig_title` empty on imported
/// records and repeats the localized title on most Chinese ones, so only a
/// genuinely different name is worth keeping.
String? neodbItemOriginalTitle(Map<String, dynamic> json, String? title) {
  final String? original = _nonEmpty(json['orig_title']);
  return original != null && original != title ? original : null;
}

/// Synopsis. `localized_description` first, then the English `description`
/// and finally the short `brief` (which repeats one of the two).
String? neodbItemDescription(Map<String, dynamic> json) {
  final String? localized = neodbChineseText(json['localized_description']);
  if (localized != null) return stripHtmlText(localized);
  return stripHtmlText(_nonEmpty(json['description'])) ??
      stripHtmlText(_nonEmpty(json['brief']));
}

/// Chinese-preferring lookup over NeoDB's `[{lang, text}]` renderings: the
/// catalogue tags the language of every rendering instead of picking one
/// canonical form, and Traditional variants outnumber `zh-cn` on some items.
String? neodbChineseText(Object? raw) {
  if (raw is! List<dynamic>) return null;
  for (final String lang in _chineseLanguageTags) {
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      if (_trimmed(entry['lang']).toLowerCase() != lang) continue;
      final String? text = _nonEmpty(entry['text']);
      if (text != null) return text;
    }
  }
  return null;
}

const List<String> _chineseLanguageTags = <String>[
  'zh-cn',
  'zh-hans',
  'zh-hant',
  'zh-tw',
  'zh',
];

/// Already on the app's 1–10 scale — NeoDB is one of the few keyless sources
/// there, so parsing it as a 0–5 score would halve every rating shown.
double? neodbItemRating(Object? raw) {
  final double? value = (raw as num?)?.toDouble();
  return (value != null && value > 0) ? value : null;
}

/// Release year. Detail responses carry `year`; search rows only list it
/// inside `tags`, which hold a decade bucket ("1990s") beside a bare year in
/// an unpredictable slot, so tags are scanned when `year` is absent.
int? neodbItemYear(Map<String, dynamic> json) {
  final int? year = _intOrNull(json['year']);
  if (_isYear(year)) return year;
  for (final String tag in _stringList(json['tags'])) {
    if (tag.length != 4) continue;
    final int? value = int.tryParse(tag);
    if (_isYear(value)) return value;
  }
  return null;
}

bool _isYear(int? value) => value != null && value >= 1800 && value <= 2099;

/// Episodes in a TV season / show record; null when the count is absent.
int? neodbItemEpisodeCount(Map<String, dynamic> json) =>
    _intOrNull(json['episode_count']);

/// `length` is a runtime in seconds; the movie model stores whole minutes.
int? neodbRuntimeMinutes(Object? raw) {
  final int? seconds = _intOrNull(raw);
  if (seconds == null || seconds <= 0) return null;
  final int minutes = (seconds / 60).round();
  return minutes > 0 ? minutes : null;
}

/// `genre` holds English slugs ("drama", "Ancient-Costum"). They pass through
/// verbatim: NeoDB ships no localized genre list, and inventing one here
/// would hide which vocabulary the user is reading.
List<String> neodbItemGenres(Object? raw) {
  final List<String> genres = <String>[];
  for (final String value in _stringList(raw)) {
    if (!genres.contains(value)) genres.add(value);
  }
  return genres;
}

/// Provider-native uuid. NeoDB mints base62 ids, so every model hashes this
/// down to its integer key.
String neodbItemUuid(Map<String, dynamic> json) => _trimmed(json['uuid']);

/// Provider-native uuid recovered from a stored NeoDB page URL. [Movie] and
/// [TvShow] key on an integer id and have no native-id column, so a cached
/// record's `externalUrl` — which this fork always writes as the NeoDB page —
/// is the only place the uuid survives a round trip through the database.
String? neodbUuidFromUrl(String? url) {
  if (url == null) return null;
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'neodb.social') return null;
  final List<String> segments = uri.pathSegments;
  return segments.isEmpty ? null : segments.last;
}

/// Cover image URL; null when the item carries no artwork.
String? neodbItemCoverUrl(Map<String, dynamic> json) =>
    _nonEmpty(json['cover_image_url']);

/// `id` arrives absolute while `url` is a site-relative path — take either.
String? neodbItemUrl(Map<String, dynamic> json) {
  final String? absolute = _nonEmpty(json['id']);
  if (absolute != null && absolute.startsWith('http')) return absolute;
  final String? path = _nonEmpty(json['url']);
  return path != null ? 'https://neodb.social$path' : null;
}

String _trimmed(Object? value) => value is String ? value.trim() : '';

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(Object? raw) {
  if (raw is! List<dynamic>) return const <String>[];
  return raw
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList();
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
