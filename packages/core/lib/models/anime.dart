import 'dart:convert';

import 'data_source.dart';
import '../utils/anime_manga_title_language.dart';
import '../utils/kitsu_status.dart';

/// Anime metadata. Cache identity is the pair `(id, source)`.
class Anime {
  const Anime({
    required this.id,
    required this.title,
    this.source = DataSource.anilist,
    this.titleEnglish,
    this.titleNative,
    this.description,
    this.coverUrl,
    this.coverUrlMedium,
    this.averageScore,
    this.meanScore,
    this.popularity,
    this.status,
    this.season,
    this.seasonYear,
    this.startYear,
    this.startMonth,
    this.startDay,
    this.episodes,
    this.duration,
    this.format,
    this.sourceMaterial,
    this.genres,
    this.tags,
    this.studios,
    this.bannerUrl,
    this.nextAiringEpisode,
    this.nextAiringAt,
    this.externalUrl,
    this.updatedAt,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? titleMap =
        json['title'] as Map<String, dynamic>?;
    final String title = titleMap?['romaji'] as String? ??
        titleMap?['english'] as String? ??
        'Unknown';

    final Map<String, dynamic>? coverMap =
        json['coverImage'] as Map<String, dynamic>?;

    final Map<String, dynamic>? dateMap =
        json['startDate'] as Map<String, dynamic>?;

    final List<dynamic>? genresList = json['genres'] as List<dynamic>?;

    // Only the name is kept; per-media spoiler / category are looked up from
    // the catalog table when needed.
    List<String>? tags;
    final List<dynamic>? tagsList = json['tags'] as List<dynamic>?;
    if (tagsList != null && tagsList.isNotEmpty) {
      tags = tagsList
          .map((dynamic t) =>
              (t as Map<String, dynamic>)['name'] as String? ?? '')
          .where((String s) => s.isNotEmpty)
          .toList();
      if (tags.isEmpty) tags = null;
    }

    List<String>? studios;
    final Map<String, dynamic>? studiosMap =
        json['studios'] as Map<String, dynamic>?;
    if (studiosMap != null) {
      final List<dynamic>? nodes = studiosMap['nodes'] as List<dynamic>?;
      if (nodes != null && nodes.isNotEmpty) {
        studios = nodes
            .map((dynamic n) =>
                (n as Map<String, dynamic>)['name'] as String? ?? '')
            .where((String s) => s.isNotEmpty)
            .toList();
        if (studios.isEmpty) studios = null;
      }
    }

    String? description = json['description'] as String?;
    if (description != null) {
      description = _stripHtml(description);
    }

    final int id = json['id'] as int;
    final Map<String, dynamic>? nextAiring =
        json['nextAiringEpisode'] as Map<String, dynamic>?;

    return Anime(
      id: id,
      title: title,
      titleEnglish: titleMap?['english'] as String?,
      titleNative: titleMap?['native'] as String?,
      description: description,
      coverUrl: (coverMap?['extraLarge'] ?? coverMap?['large']) as String?,
      coverUrlMedium: coverMap?['medium'] as String?,
      averageScore: json['averageScore'] as int?,
      status: json['status'] as String?,
      startYear: dateMap?['year'] as int?,
      startMonth: dateMap?['month'] as int?,
      startDay: dateMap?['day'] as int?,
      episodes: json['episodes'] as int?,
      duration: json['duration'] as int?,
      format: json['format'] as String?,
      sourceMaterial: json['source'] as String?,
      genres: genresList?.map((dynamic g) => g as String).toList(),
      tags: tags,
      studios: studios,
      bannerUrl: json['bannerImage'] as String?,
      nextAiringEpisode: nextAiring?['episode'] as int?,
      nextAiringAt: nextAiring?['airingAt'] as int?,
      externalUrl: 'https://anilist.co/anime/$id',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Builds an [Anime] from a Kitsu `/anime` JSON:API resource
  /// ({id, attributes}).
  factory Anime.fromKitsu(Map<String, dynamic> json) {
    final int id = int.parse(json['id'] as String);
    final Map<String, dynamic> attrs =
        (json['attributes'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

    final Map<String, dynamic> titles =
        (attrs['titles'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final String? canonical = _nonEmpty(attrs['canonicalTitle']);
    final String? english = _nonEmpty(titles['en']);
    final String? romaji = _nonEmpty(titles['en_jp']) ?? canonical;
    final String? native = _nonEmpty(titles['ja_jp']);
    final String title =
        _firstNonEmpty(<String?>[romaji, english, native, canonical]) ??
            'Unknown';

    final Map<String, dynamic>? poster =
        attrs['posterImage'] as Map<String, dynamic>?;
    final Map<String, dynamic>? banner =
        attrs['coverImage'] as Map<String, dynamic>?;

    int? startYear;
    final String? startDate = attrs['startDate'] as String?;
    if (startDate != null && startDate.length >= 4) {
      startYear = int.tryParse(startDate.substring(0, 4));
    }

    final String? rating = attrs['averageRating'] as String?;
    final double? ratingValue = rating != null ? double.tryParse(rating) : null;

    final Object? slug = attrs['slug'];
    final String path = slug is String && slug.isNotEmpty ? slug : '$id';

    return Anime(
      id: id,
      source: DataSource.kitsu,
      title: title,
      titleEnglish: english,
      titleNative: native,
      description: _stripHtml(attrs['synopsis'] as String?),
      coverUrl: (poster?['original'] ?? poster?['large']) as String?,
      coverUrlMedium: poster?['medium'] as String?,
      // Kitsu's `coverImage` is the wide banner (its `posterImage` is the
      // cover) — mapped to bannerUrl like AniList's bannerImage.
      bannerUrl: (banner?['original'] ?? banner?['large']) as String?,
      averageScore: ratingValue?.round(),
      status: kitsuStatusVocab(attrs['status'] as String?),
      startYear: startYear,
      episodes: (attrs['episodeCount'] as num?)?.toInt(),
      duration: (attrs['episodeLength'] as num?)?.toInt(),
      format: _kitsuFormat(attrs['subtype'] as String?),
      externalUrl: 'https://kitsu.io/anime/$path',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Bangumi search / subject payload. `name` is the original title and
  /// `name_cn` the Chinese one; Chinese takes the [title] slot so the default
  /// title language reads Chinese, and [titleNative] keeps the original.
  factory Anime.fromBangumi(Map<String, dynamic> json) {
    final int id = (json['id'] as num).toInt();

    final String? original = _nonEmpty(json['name']);
    final String? chinese = _nonEmpty(json['name_cn']);
    final String title =
        _firstNonEmpty(<String?>[chinese, original]) ?? 'Unknown';

    final Map<String, dynamic> images =
        (json['images'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    final Map<String, dynamic> rating =
        (json['rating'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final num? score = rating['score'] as num?;

    // Calendar rows carry `air_date`; search and subject rows carry `date`.
    final String? date =
        _nonEmpty(json['date']) ?? _nonEmpty(json['air_date']);

    return Anime(
      id: id,
      source: DataSource.bangumi,
      title: title,
      titleNative: original,
      description: _nonEmpty(json['summary']),
      coverUrl: _nonEmpty(images['large']) ?? _nonEmpty(json['image']),
      coverUrlMedium: _nonEmpty(images['common']),
      // Bangumi rates 0–10 where Anime stores AniList's 0–100.
      averageScore: score != null ? (score * 10).round() : null,
      status: _bangumiStatus(date),
      startYear: _bangumiDatePart(date, 0),
      startMonth: _bangumiDatePart(date, 1),
      startDay: _bangumiDatePart(date, 2),
      episodes: (json['eps'] as num?)?.toInt(),
      format: _bangumiFormat(_nonEmpty(json['platform'])),
      tags: _bangumiTagNames(json['tags']),
      studios: _bangumiStudios(_bangumiInfobox(json['infobox'])),
      externalUrl: 'https://bgm.tv/subject/$id',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  factory Anime.fromDb(Map<String, dynamic> row) {
    List<String>? genres;
    if (row['genres'] != null && (row['genres'] as String).isNotEmpty) {
      try {
        genres = (jsonDecode(row['genres'] as String) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList();
      } on FormatException {
        genres = null;
      }
    }

    List<String>? studios;
    if (row['studios'] != null && (row['studios'] as String).isNotEmpty) {
      try {
        studios = (jsonDecode(row['studios'] as String) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList();
      } on FormatException {
        studios = null;
      }
    }

    List<String>? tags;
    if (row['tags'] != null && (row['tags'] as String).isNotEmpty) {
      try {
        tags = (jsonDecode(row['tags'] as String) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList();
      } on FormatException {
        tags = null;
      }
    }

    // Before v60 `source` held the source material ("MANGA"), not the provider,
    // so an unrecognised value is read as one.
    final String? rawSource = row['source'] as String?;
    final DataSource? knownSource = DataSource.tryFromName(rawSource);
    final String? sourceMaterial = (row['source_material'] as String?) ??
        (knownSource == null ? rawSource : null);

    return Anime(
      id: row['id'] as int,
      source: knownSource ?? DataSource.anilist,
      title: row['title'] as String,
      titleEnglish: row['title_english'] as String?,
      titleNative: row['title_native'] as String?,
      description: row['description'] as String?,
      coverUrl: row['cover_url'] as String?,
      coverUrlMedium: row['cover_url_medium'] as String?,
      averageScore: row['average_score'] as int?,
      meanScore: row['mean_score'] as int?,
      popularity: row['popularity'] as int?,
      status: row['status'] as String?,
      season: row['season'] as String?,
      seasonYear: row['season_year'] as int?,
      startYear: row['start_year'] as int?,
      startMonth: row['start_month'] as int?,
      startDay: row['start_day'] as int?,
      episodes: row['episodes'] as int?,
      duration: row['duration'] as int?,
      format: row['format'] as String?,
      sourceMaterial: sourceMaterial,
      genres: genres,
      tags: tags,
      studios: studios,
      bannerUrl: row['banner_url'] as String?,
      nextAiringEpisode: row['next_airing_episode'] as int?,
      nextAiringAt: row['next_airing_at'] as int?,
      externalUrl: row['external_url'] as String?,
      updatedAt: row['updated_at'] as int?,
    );
  }

  final int id;

  /// Provider this record came from; part of the cache identity `(id, source)`.
  final DataSource source;

  /// Romaji title (always present per AniList contract).
  final String title;

  final String? titleEnglish;
  final String? titleNative;

  /// Returns the title in the requested AniList language with a fallback chain.
  String titleByLanguage(String lang) {
    return pickAnimeMangaTitle(
          lang: lang,
          romaji: title,
          english: titleEnglish,
          native: titleNative,
        ) ??
        title;
  }

  final String? description;
  final String? coverUrl;
  final String? coverUrlMedium;
  final int? averageScore;
  final int? meanScore;
  final int? popularity;

  /// One of FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS.
  final String? status;

  /// One of WINTER, SPRING, SUMMER, FALL.
  final String? season;

  final int? seasonYear;
  final int? startYear;
  final int? startMonth;
  final int? startDay;

  /// Null when ongoing or unknown.
  final int? episodes;

  /// Per-episode runtime in minutes.
  final int? duration;

  /// One of TV, TV_SHORT, MOVIE, SPECIAL, OVA, ONA, MUSIC.
  final String? format;

  /// Source material: ORIGINAL, MANGA, LIGHT_NOVEL, VISUAL_NOVEL, VIDEO_GAME.
  final String? sourceMaterial;

  final List<String>? genres;

  /// AniList tag names; per-media category / rank / spoiler flags are not
  /// stored — only the catalog table keeps that metadata.
  final List<String>? tags;

  final List<String>? studios;
  final String? bannerUrl;
  final int? nextAiringEpisode;
  final int? nextAiringAt;
  final String? externalUrl;

  /// Unix timestamp of when this row was cached.
  final int? updatedAt;

  double? get rating10 =>
      averageScore != null ? averageScore! / 10.0 : null;

  String? get formattedRating => rating10?.toStringAsFixed(1);

  int? get releaseYear => seasonYear ?? startYear;

  String? get genresString => genres?.join(', ');

  String? get tagsString => tags?.join(', ');

  String? get studiosString => studios?.join(', ');

  String? get formatLabel => animeFormatLabel(format);

  /// Maps an AniList anime [format] code to a display label.
  /// Returns the raw code for unrecognised values and `null` when absent.
  static String? animeFormatLabel(String? format) => switch (format) {
        'TV' => 'TV',
        'TV_SHORT' => 'TV Short',
        'MOVIE' => 'Movie',
        'SPECIAL' => 'Special',
        'OVA' => 'OVA',
        'ONA' => 'ONA',
        'MUSIC' => 'Music',
        _ => format,
      };

  String? get statusLabel => switch (status) {
        'FINISHED' => 'Finished',
        'RELEASING' => 'Airing',
        'NOT_YET_RELEASED' => 'Not Yet Aired',
        'CANCELLED' => 'Cancelled',
        'HIATUS' => 'Hiatus',
        _ => status,
      };

  String? get seasonLabel {
    if (season == null) return null;
    final String seasonName = switch (season) {
      'WINTER' => 'Winter',
      'SPRING' => 'Spring',
      'SUMMER' => 'Summer',
      'FALL' => 'Fall',
      _ => season!,
    };
    return seasonYear != null ? '$seasonName $seasonYear' : seasonName;
  }

  String get episodesString =>
      episodes != null ? '$episodes ep' : '? ep';

  String? get durationString =>
      duration != null ? '$duration min/ep' : null;

  String? get sourceLabel => switch (sourceMaterial) {
        'ORIGINAL' => 'Original',
        'MANGA' => 'Based on Manga',
        'LIGHT_NOVEL' => 'Based on Light Novel',
        'VISUAL_NOVEL' => 'Based on Visual Novel',
        'VIDEO_GAME' => 'Based on Video Game',
        'OTHER' => 'Other',
        _ => sourceMaterial,
      };

  bool get hasNextAiring =>
      nextAiringEpisode != null && nextAiringAt != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Anime && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Anime(id: $id, title: $title)';

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      'id': id,
      'source': source.name,
      'title': title,
      'title_english': titleEnglish,
      'title_native': titleNative,
      'description': description,
      'cover_url': coverUrl,
      'cover_url_medium': coverUrlMedium,
      'average_score': averageScore,
      'mean_score': meanScore,
      'popularity': popularity,
      'status': status,
      'season': season,
      'season_year': seasonYear,
      'start_year': startYear,
      'start_month': startMonth,
      'start_day': startDay,
      'episodes': episodes,
      'duration': duration,
      'format': format,
      'source_material': sourceMaterial,
      'genres': genres != null ? jsonEncode(genres) : null,
      'tags': tags != null ? jsonEncode(tags) : null,
      'studios': studios != null ? jsonEncode(studios) : null,
      'banner_url': bannerUrl,
      'next_airing_episode': nextAiringEpisode,
      'next_airing_at': nextAiringAt,
      'external_url': externalUrl,
      'updated_at':
          updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// `toDb` minus the cache timestamp, for `.xcoll` / `.xcollx` payloads.
  Map<String, dynamic> toExport() {
    final Map<String, dynamic> data = toDb();
    data.remove('updated_at');
    return data;
  }

  Anime copyWith({
    int? id,
    DataSource? source,
    String? title,
    String? titleEnglish,
    String? titleNative,
    String? description,
    String? coverUrl,
    String? coverUrlMedium,
    int? averageScore,
    int? meanScore,
    int? popularity,
    String? status,
    String? season,
    int? seasonYear,
    int? startYear,
    int? startMonth,
    int? startDay,
    int? episodes,
    int? duration,
    String? format,
    String? sourceMaterial,
    List<String>? genres,
    List<String>? tags,
    List<String>? studios,
    String? bannerUrl,
    int? nextAiringEpisode,
    int? nextAiringAt,
    String? externalUrl,
    int? updatedAt,
  }) {
    return Anime(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      coverUrlMedium: coverUrlMedium ?? this.coverUrlMedium,
      averageScore: averageScore ?? this.averageScore,
      meanScore: meanScore ?? this.meanScore,
      popularity: popularity ?? this.popularity,
      status: status ?? this.status,
      season: season ?? this.season,
      seasonYear: seasonYear ?? this.seasonYear,
      startYear: startYear ?? this.startYear,
      startMonth: startMonth ?? this.startMonth,
      startDay: startDay ?? this.startDay,
      episodes: episodes ?? this.episodes,
      duration: duration ?? this.duration,
      format: format ?? this.format,
      sourceMaterial: sourceMaterial ?? this.sourceMaterial,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      studios: studios ?? this.studios,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      nextAiringEpisode: nextAiringEpisode ?? this.nextAiringEpisode,
      nextAiringAt: nextAiringAt ?? this.nextAiringAt,
      externalUrl: externalUrl ?? this.externalUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _nonEmpty(Object? value) =>
      (value is String && value.isNotEmpty) ? value : null;

  static String? _firstNonEmpty(List<String?> values) {
    for (final String? v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Maps Kitsu anime `subtype` onto the AniList-style format vocabulary.
  static String? _kitsuFormat(String? subtype) => switch (subtype) {
        'TV' => 'TV',
        'movie' => 'MOVIE',
        'special' => 'SPECIAL',
        'OVA' => 'OVA',
        'ONA' => 'ONA',
        'music' => 'MUSIC',
        _ => null,
      };

  /// Bangumi tags are community votes ordered by count, so the head of the list
  /// carries the meaning and the tail is one-off spelling variants.
  static const int _bangumiMaxTags = 12;

  static List<String>? _bangumiTagNames(Object? raw) {
    if (raw is! List<dynamic>) return null;
    final List<String> out = <String>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final String? name = _nonEmpty(entry['name']);
      if (name != null) out.add(name);
      if (out.length >= _bangumiMaxTags) break;
    }
    return out.isEmpty ? null : out;
  }

  /// Flattens Bangumi's `infobox` list into a `key -> raw value` map.
  static Map<String, dynamic> _bangumiInfobox(Object? raw) {
    if (raw is! List<dynamic>) return const <String, dynamic>{};
    final Map<String, dynamic> out = <String, dynamic>{};
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final Object? key = entry['key'];
      if (key is String && key.isNotEmpty) out[key] = entry['value'];
    }
    return out;
  }

  /// The studio, from the dedicated key first and the production committee
  /// second. Bangumi may list several, joined by ` / `.
  static List<String>? _bangumiStudios(Map<String, dynamic> infobox) {
    for (final String key in const <String>['动画制作', '製作', '制作']) {
      final List<String> names = _bangumiInfoboxValues(infobox[key]);
      if (names.isNotEmpty) return names;
    }
    return null;
  }

  /// An infobox value is a bare string or a list of `{'v': ...}` maps; either
  /// can pack several names into one ` / ` separated string.
  static List<String> _bangumiInfoboxValues(Object? raw) {
    final List<Object?> entries = switch (raw) {
      final String value => <Object?>[value],
      final List<dynamic> list => list,
      _ => const <Object?>[],
    };
    final List<String> out = <String>[];
    for (final Object? entry in entries) {
      final String? value = switch (entry) {
        final String s => s,
        final Map<String, dynamic> m => _nonEmpty(m['v']),
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

  /// Bangumi dates are `YYYY-MM-DD`; partial values (`2024-04`) leave the
  /// trailing parts null.
  static int? _bangumiDatePart(String? date, int index) {
    if (date == null) return null;
    final List<String> parts = date.split('-');
    return parts.length > index ? int.tryParse(parts[index]) : null;
  }

  /// Bangumi carries no airing flag, so only the case needing no inference is
  /// derived: a start date still in the future.
  static String? _bangumiStatus(String? date) {
    final DateTime? start = date == null ? null : DateTime.tryParse(date);
    if (start == null) return null;
    return start.isAfter(DateTime.now()) ? 'NOT_YET_RELEASED' : null;
  }

  /// Maps Bangumi's `platform` onto the AniList format vocabulary. The Chinese
  /// literals are the API's own values, not prose.
  static String? _bangumiFormat(String? platform) => switch (platform) {
        'TV' => 'TV',
        'WEB' || '动态漫画' => 'ONA',
        'OVA' || 'OAD' => 'OVA',
        '剧场版' || '剧场版动画' => 'MOVIE',
        _ => null,
      };

  static final RegExp _htmlTagPattern = RegExp('<[^>]*>');

  static String? _stripHtml(String? text) {
    if (text == null) return null;
    String clean = text.replaceAll(_htmlTagPattern, '');
    clean = clean.replaceAll('&amp;', '&');
    clean = clean.replaceAll('&lt;', '<');
    clean = clean.replaceAll('&gt;', '>');
    clean = clean.replaceAll('&quot;', '"');
    clean = clean.replaceAll('&#39;', "'");
    clean = clean.replaceAll('&nbsp;', ' ');
    clean = clean.trim();
    return clean.isEmpty ? null : clean;
  }
}
