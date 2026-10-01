import 'dart:convert';

import 'data_source.dart';
import '../utils/anime_manga_title_language.dart';
import '../utils/bangumi_json.dart';
import '../utils/kitsu_status.dart';
import '../utils/stable_id.dart';

/// [id] is the provider-side id and is not unique across providers — the
/// cache identity is the pair `(id, source)`.
class Manga {
  const Manga({
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
    this.startYear,
    this.startMonth,
    this.startDay,
    this.chapters,
    this.volumes,
    this.format,
    this.countryOfOrigin,
    this.genres,
    this.tags,
    this.authors,
    this.externalUrl,
    this.updatedAt,
    this.bannerUrl,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? titleMap = _jsonMap(json['title']);
    final String title =
        _jsonString(titleMap?['romaji']) ??
        _jsonString(titleMap?['english']) ??
        'Unknown';

    final Map<String, dynamic>? coverMap = _jsonMap(json['coverImage']);

    final Map<String, dynamic>? dateMap = _jsonMap(json['startDate']);

    final List<dynamic>? genresList = _jsonList(json['genres']);

    // Only the name is kept; per-media spoiler / category are looked up from
    // the catalog table when needed.
    List<String>? tags;
    final List<dynamic>? tagsList = _jsonList(json['tags']);
    if (tagsList != null && tagsList.isNotEmpty) {
      tags = tagsList
          .map((Object? t) {
            final Map<String, dynamic>? tag = _jsonMap(t);
            final String? name = tag == null ? null : _jsonString(tag['name']);
            return name ?? '';
          })
          .where((String s) => s.isNotEmpty)
          .toList();
      if (tags.isEmpty) tags = null;
    }

    // Filter staff edges to author-credit roles only (Story, Art, Story & Art).
    List<String>? authors;
    final Map<String, dynamic>? staffMap = _jsonMap(json['staff']);
    if (staffMap != null) {
      final List<dynamic>? edges = _jsonList(staffMap['edges']);
      if (edges != null) {
        authors = edges
            .where((Object? e) {
              final Map<String, dynamic>? edge = _jsonMap(e);
              final String? role = edge == null
                  ? null
                  : _jsonString(edge['role']);
              return role == 'Story' || role == 'Art' || role == 'Story & Art';
            })
            .map((Object? e) {
              final Map<String, dynamic>? edge = _jsonMap(e);
              final Map<String, dynamic>? node = edge == null
                  ? null
                  : _jsonMap(edge['node']);
              final Map<String, dynamic>? name = node == null
                  ? null
                  : _jsonMap(node['name']);
              return _jsonString(name?['full']) ?? '';
            })
            .where((String s) => s.isNotEmpty)
            .toList();
        if (authors.isEmpty) authors = null;
      }
    }

    String? description = _jsonString(json['description']);
    if (description != null) {
      description = _stripHtml(description);
    }

    final int id = _jsonInt(json['id']) ?? 0;

    return Manga(
      id: id,
      title: title,
      titleEnglish: _jsonString(titleMap?['english']),
      titleNative: _jsonString(titleMap?['native']),
      description: description,
      coverUrl:
          _jsonString(coverMap?['extraLarge']) ??
          _jsonString(coverMap?['large']),
      coverUrlMedium: _jsonString(coverMap?['medium']),
      averageScore: _jsonInt(json['averageScore']),
      status: _jsonString(json['status']),
      startYear: _jsonInt(dateMap?['year']),
      startMonth: _jsonInt(dateMap?['month']),
      startDay: _jsonInt(dateMap?['day']),
      chapters: _jsonInt(json['chapters']),
      volumes: _jsonInt(json['volumes']),
      format: _jsonString(json['format']),
      genres: genresList
          ?.map((Object? g) => g is String ? g : null)
          .whereType<String>()
          .toList(),
      tags: tags,
      authors: authors,
      externalUrl: 'https://anilist.co/manga/$id',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      bannerUrl: _jsonString(json['bannerImage']),
    );
  }

  /// MangaBaka's flat REST shape differs from AniList: top-level titles,
  /// string chapter / volume counts, a 0–100 rating, raw cover variant only.
  factory Manga.fromMangaBaka(Map<String, dynamic> json) {
    final int id = _jsonInt(json['id']) ?? 0;

    final List<Map<String, dynamic>> titles =
        _jsonList(
          json['titles'],
        )?.whereType<Map<String, dynamic>>().toList() ??
        const <Map<String, dynamic>>[];

    // Mapped onto AniList's romaji / english / native slots so the title-language
    // setting behaves alike. `ja-Latn` is the real romaji; the flat field is not.
    final String? romaji =
        _bakaTitle(titles, 'ja-Latn') ?? _jsonString(json['romanized_title']);
    final String? native =
        _bakaTitle(titles, 'ja') ?? _jsonString(json['native_title']);
    final String? english =
        _bakaTitle(titles, 'en') ?? _jsonString(json['title']);
    final String title =
        _firstNonEmpty(<String?>[romaji, english, native]) ?? 'Unknown';

    String? coverUrl;
    final Object? cover = json['cover'];
    if (cover is Map<String, dynamic>) {
      final Object? raw = cover['raw'];
      if (raw is Map<String, dynamic>) {
        coverUrl = _jsonString(raw['url']);
      } else if (raw is String) {
        coverUrl = raw;
      }
    }

    int? startYear;
    final Object? published = json['published'];
    if (published is Map<String, dynamic>) {
      final String? start = _jsonString(published['start_date']);
      if (start != null && start.length >= 4) {
        startYear = int.tryParse(start.substring(0, 4));
      }
    }
    startYear ??= _jsonInt(json['year']);

    final List<String>? genres = _stringList(json['genres']);
    final List<String>? tags = _stringList(json['tags']);

    final List<String> authors = <String>[
      ...?_stringList(json['authors']),
      ...?_stringList(json['artists']),
    ];

    final num? rating = json['rating'] is num ? json['rating'] as num : null;

    String? description = _jsonString(json['description']);
    if (description != null) description = _stripHtml(description);

    return Manga(
      id: id,
      source: DataSource.mangabaka,
      title: title,
      titleEnglish: english,
      titleNative: native,
      description: description,
      coverUrl: coverUrl,
      averageScore: rating?.round(),
      status: _mangaBakaStatus(_jsonString(json['status'])),
      startYear: startYear,
      chapters: _parseIntOrNull(json['total_chapters']),
      volumes: _parseIntOrNull(json['final_volume']),
      format: _mangaBakaFormat(_jsonString(json['type'])),
      genres: genres,
      tags: tags,
      authors: authors.isEmpty ? null : authors,
      externalUrl: 'https://mangabaka.org/$id',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// MangaDex ids are UUIDs, so [id] is an [fnv1a64] hash and the UUID survives
  /// in [externalUrl]. Chapter counts need `/aggregate`, so search rows lack them.
  factory Manga.fromMangaDex(Map<String, dynamic> json) {
    final String uuid = _jsonString(json['id']) ?? '';
    final Map<String, dynamic> attrs =
        _jsonMap(json['attributes']) ?? const <String, dynamic>{};

    final Map<String, dynamic> titleMap =
        _jsonMap(attrs['title']) ?? const <String, dynamic>{};
    final List<Map<String, dynamic>> altTitles =
        _jsonList(
          attrs['altTitles'],
        )?.whereType<Map<String, dynamic>>().toList() ??
        const <Map<String, dynamic>>[];

    String? pickTitle(String lang) {
      final Object? primary = titleMap[lang];
      if (primary is String && primary.isNotEmpty) return primary;
      for (final Map<String, dynamic> alt in altTitles) {
        final Object? v = alt[lang];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    // Chinese first. A MangaDex record never carries a Chinese name in `title`
    // — it sits in `altTitles` as `zh` (Simplified) or `zh-hk` (Traditional),
    // and only about three records in five have one at all. Leading with it is
    // the point of this fork: searching 海贼王 should show 航海王, not
    // "One Piece". Records without one keep their romaji / English title.
    final String? chinese = _firstNonEmpty(<String?>[
      for (final String lang in _zhTitleKeys) pickTitle(lang),
    ]);
    final String? english = pickTitle('en');
    final String? romaji = pickTitle('ja-ro') ?? english;
    final String? native = pickTitle('ja') ?? pickTitle('ko');
    final String title =
        _firstNonEmpty(<String?>[chinese, romaji, english, native]) ??
        'Unknown';

    final List<dynamic> relationships =
        _jsonList(json['relationships']) ?? const <dynamic>[];
    String? coverUrl;
    final List<String> authors = <String>[];
    for (final Map<String, dynamic> rel
        in relationships.whereType<Map<String, dynamic>>()) {
      final Map<String, dynamic>? relAttrs = _jsonMap(rel['attributes']);
      switch (rel['type']) {
        case 'cover_art':
          final Object? file = relAttrs?['fileName'];
          if (file is String && file.isNotEmpty) {
            coverUrl =
                'https://uploads.mangadex.org/covers/$uuid/$file.512.jpg';
          }
        case 'author':
        case 'artist':
          final Object? name = relAttrs?['name'];
          if (name is String && name.isNotEmpty && !authors.contains(name)) {
            authors.add(name);
          }
      }
    }

    final List<String> genres = <String>[];
    final List<String> tags = <String>[];
    for (final Map<String, dynamic> tag
        in _jsonList(attrs['tags'])?.whereType<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[]) {
      final Map<String, dynamic>? tagAttrs = _jsonMap(tag['attributes']);
      final String? name = _localized(tagAttrs?['name']);
      if (name == null) continue;
      if (tagAttrs?['group'] == 'genre') {
        genres.add(name);
      } else if (tagAttrs?['group'] == 'theme') {
        tags.add(name);
      }
    }

    return Manga(
      id: fnv1a64(uuid),
      source: DataSource.mangadex,
      title: title,
      titleEnglish: english,
      titleNative: native,
      description: _stripHtml(_localized(attrs['description'])),
      coverUrl: coverUrl,
      status: _mangaDexStatus(_jsonString(attrs['status'])),
      startYear: _jsonInt(attrs['year']),
      // Final numbers on the manga object itself, populated for completed series
      // — an inline counter without the `/aggregate` call. getByUuid refines them.
      chapters: _parseCount(attrs['lastChapter']),
      volumes: _parseCount(attrs['lastVolume']),
      format: _mangaDexFormat(_jsonString(attrs['originalLanguage'])),
      genres: genres.isEmpty ? null : genres,
      tags: tags.isEmpty ? null : tags,
      authors: authors.isEmpty ? null : authors,
      externalUrl: 'https://mangadex.org/title/$uuid',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Genres are related JSON:API resources not requested here, so they stay
  /// null.
  factory Manga.fromKitsu(Map<String, dynamic> json) {
    final int id = _jsonInt(json['id']) ?? 0;
    final Map<String, dynamic> attrs =
        _jsonMap(json['attributes']) ?? const <String, dynamic>{};

    final Map<String, dynamic> titles =
        _jsonMap(attrs['titles']) ?? const <String, dynamic>{};
    final String? canonical = _nonEmpty(attrs['canonicalTitle']);
    final String? english = _nonEmpty(titles['en']);
    final String? romaji = _nonEmpty(titles['en_jp']) ?? canonical;
    final String? native = _nonEmpty(titles['ja_jp']);
    final String title =
        _firstNonEmpty(<String?>[romaji, english, native, canonical]) ??
        'Unknown';

    final Map<String, dynamic>? poster = _jsonMap(attrs['posterImage']);
    final Map<String, dynamic>? banner = _jsonMap(attrs['coverImage']);

    int? startYear;
    final String? startDate = _jsonString(attrs['startDate']);
    if (startDate != null && startDate.length >= 4) {
      startYear = int.tryParse(startDate.substring(0, 4));
    }

    final String? rating = _jsonString(attrs['averageRating']);
    final double? ratingValue = rating != null ? double.tryParse(rating) : null;

    final Object? slug = attrs['slug'];
    final String path = slug is String && slug.isNotEmpty ? slug : '$id';

    return Manga(
      id: id,
      source: DataSource.kitsu,
      title: title,
      titleEnglish: english,
      titleNative: native,
      description: _stripHtml(_jsonString(attrs['synopsis'])),
      coverUrl:
          _jsonString(poster?['original']) ?? _jsonString(poster?['large']),
      coverUrlMedium: _jsonString(poster?['medium']),
      // Kitsu's `coverImage` is the wide banner (its `posterImage` is the cover)
      // — mapped to bannerUrl like AniList's bannerImage.
      bannerUrl:
          _jsonString(banner?['original']) ?? _jsonString(banner?['large']),
      averageScore: ratingValue?.round(),
      status: kitsuStatusVocab(_jsonString(attrs['status'])),
      startYear: startYear,
      chapters: _jsonInt(attrs['chapterCount']),
      volumes: _jsonInt(attrs['volumeCount']),
      format: _kitsuFormat(_jsonString(attrs['subtype'])),
      externalUrl: 'https://kitsu.io/manga/$path',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Bangumi book subject. The manga source narrows the search to the 漫画
  /// meta tag, so a row reaching here is a comic and [format] is always MANGA.
  ///
  /// Bangumi states a run's length as `eps` (chapters) and `volumes`, and
  /// answers 0 rather than omitting the key, so 0 must read as unknown.
  /// Serialisation exists only as a meta tag (连载中 / 已完结), which is what
  /// keeps [status] from being empty where AniList would have said RELEASING.
  factory Manga.fromBangumi(Map<String, dynamic> json) {
    final int id = bangumiSubjectId(json);
    final String? date = bangumiSubjectDate(json);

    return Manga(
      id: id,
      source: DataSource.bangumi,
      title: bangumiSubjectTitle(json) ?? 'Unknown',
      titleNative: bangumiSubjectOriginalTitle(json),
      description: bangumiSubjectSummary(json),
      coverUrl: bangumiCoverUrl(json),
      coverUrlMedium: bangumiCoverUrlMedium(json),
      averageScore: bangumiAverageScore(json),
      status: bangumiMangaStatus(date, json['meta_tags']),
      startYear: bangumiDatePart(date, 0),
      startMonth: bangumiDatePart(date, 1),
      startDay: bangumiDatePart(date, 2),
      chapters: bangumiCount(json['eps']),
      volumes: bangumiCount(json['volumes']),
      format: bangumiMangaFormat(_nonEmpty(json['platform'])),
      tags: bangumiTagNames(json['tags']),
      authors: bangumiMangaAuthors(bangumiInfobox(json['infobox'])),
      externalUrl: 'https://bgm.tv/subject/$id',
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  factory Manga.fromDb(Map<String, dynamic> row) {
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

    List<String>? authors;
    if (row['authors'] != null && (row['authors'] as String).isNotEmpty) {
      try {
        authors = (jsonDecode(row['authors'] as String) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList();
      } on FormatException {
        authors = null;
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

    return Manga(
      id: row['id'] as int,
      source: DataSource.fromName(row['source'] as String?),
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
      startYear: row['start_year'] as int?,
      startMonth: row['start_month'] as int?,
      startDay: row['start_day'] as int?,
      chapters: row['chapters'] as int?,
      volumes: row['volumes'] as int?,
      format: row['format'] as String?,
      countryOfOrigin: row['country_of_origin'] as String?,
      genres: genres,
      tags: tags,
      authors: authors,
      externalUrl: row['external_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      updatedAt: row['updated_at'] as int?,
    );
  }

  /// Provider-side id. Maps to `collection_items.external_id` and the `id`
  /// column of `manga_cache`. NOT unique without [source].
  final int id;

  /// Part of the cache identity `(id, source)` so AniList and MangaBaka entries
  /// sharing a numeric id never collide.
  final DataSource source;

  /// Display title, never empty. AniList fills it with romaji and Kitsu with
  /// the canonical title; MangaDex leads with the Chinese name when the record
  /// has one; a Chinese catalogue (Douban) puts the Chinese title here outright.
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

  final int? startYear;
  final int? startMonth;
  final int? startDay;

  /// Null when ongoing or unknown.
  final int? chapters;

  /// Null when ongoing or unknown.
  final int? volumes;

  /// One of MANGA, NOVEL, ONE_SHOT, MANHWA, MANHUA, LIGHT_NOVEL.
  final String? format;

  /// JP, KR, CN, TW.
  final String? countryOfOrigin;

  final List<String>? genres;

  /// AniList tag names; per-media category / rank / spoiler flags are not
  /// stored — only the catalog table keeps that metadata.
  final List<String>? tags;

  final List<String>? authors;
  final String? externalUrl;

  /// Unix timestamp of when this row was cached.
  final int? updatedAt;

  /// Transient — not persisted (only present on fresh API responses).
  final String? bannerUrl;

  /// Recovered from [externalUrl]; the numeric [id] is a hash of it, so this is
  /// the only way back to MangaDex's API.
  String? get mangaDexUuid {
    if (source != DataSource.mangadex) return null;
    final String? last = externalUrl?.split('/').last;
    return (last != null && last.isNotEmpty) ? last : null;
  }

  double? get rating10 => averageScore != null ? averageScore! / 10.0 : null;

  String? get formattedRating => rating10?.toStringAsFixed(1);

  int? get releaseYear => startYear;

  String? get genresString => genres?.join(', ');

  String? get tagsString => tags?.join(', ');

  String? get authorsString => authors?.join(', ');

  String? get formatLabel => mangaFormatLabel(format);

  /// Maps an AniList / MangaBaka manga [format] code to a display label.
  /// Returns the raw code for unrecognised values and `null` when absent.
  static String? mangaFormatLabel(String? format) => switch (format) {
    'MANGA' => 'Manga',
    'NOVEL' => 'Novel',
    'ONE_SHOT' => 'One-shot',
    'MANHWA' => 'Manhwa',
    'MANHUA' => 'Manhua',
    'LIGHT_NOVEL' => 'Light Novel',
    _ => format,
  };

  String? get statusLabel => switch (status) {
    'FINISHED' => 'Finished',
    'RELEASING' => 'Releasing',
    'NOT_YET_RELEASED' => 'Not Yet Released',
    'CANCELLED' => 'Cancelled',
    'HIATUS' => 'Hiatus',
    _ => status,
  };

  String get progressString {
    final String ch = chapters != null ? '$chapters ch' : '? ch';
    final String vol = volumes != null ? ' · $volumes vol' : '';
    return '$ch$vol';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Manga && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Manga(id: $id, title: $title)';

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
      'start_year': startYear,
      'start_month': startMonth,
      'start_day': startDay,
      'chapters': chapters,
      'volumes': volumes,
      'format': format,
      'country_of_origin': countryOfOrigin,
      'genres': genres != null ? jsonEncode(genres) : null,
      'tags': tags != null ? jsonEncode(tags) : null,
      'authors': authors != null ? jsonEncode(authors) : null,
      'external_url': externalUrl,
      'banner_url': bannerUrl,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// `toDb` minus the cache timestamp, for `.xcoll` / `.xcollx` payloads.
  Map<String, dynamic> toExport() {
    final Map<String, dynamic> data = toDb();
    data.remove('updated_at');
    return data;
  }

  Manga copyWith({
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
    int? startYear,
    int? startMonth,
    int? startDay,
    int? chapters,
    int? volumes,
    String? format,
    String? countryOfOrigin,
    List<String>? genres,
    List<String>? tags,
    List<String>? authors,
    String? externalUrl,
    int? updatedAt,
    String? bannerUrl,
  }) {
    return Manga(
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
      startYear: startYear ?? this.startYear,
      startMonth: startMonth ?? this.startMonth,
      startDay: startDay ?? this.startDay,
      chapters: chapters ?? this.chapters,
      volumes: volumes ?? this.volumes,
      format: format ?? this.format,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      authors: authors ?? this.authors,
      externalUrl: externalUrl ?? this.externalUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      bannerUrl: bannerUrl ?? this.bannerUrl,
    );
  }

  /// Picks the best MangaBaka title for a language code, preferring the
  /// primary / official variant. Returns null when no title matches.
  static String? _bakaTitle(List<Map<String, dynamic>> titles, String lang) {
    final List<Map<String, dynamic>> matches = titles
        .where((Map<String, dynamic> t) => t['language'] == lang)
        .toList();
    if (matches.isEmpty) return null;
    int score(Map<String, dynamic> t) {
      int s = 0;
      if (t['is_primary'] == true) s += 2;
      final Object? traits = t['traits'];
      if (traits is List && traits.contains('official')) s += 1;
      return s;
    }

    matches.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          score(b).compareTo(score(a)),
    );
    final Object? title = matches.first['title'];
    return (title is String && title.isNotEmpty) ? title : null;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final String? v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// MangaBaka returns chapter / volume counts as strings (e.g. `"147"`).
  static int? _parseIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List<dynamic>) return null;
    final List<String> out = value
        .whereType<String>()
        .where((String s) => s.isNotEmpty)
        .toList();
    return out.isEmpty ? null : out;
  }

  /// Maps MangaBaka `status` onto the AniList-style vocabulary used across the
  /// app ([statusLabel], progress UI).
  static String? _mangaBakaStatus(String? status) => switch (status) {
    'releasing' => 'RELEASING',
    'completed' => 'FINISHED',
    'hiatus' => 'HIATUS',
    'cancelled' => 'CANCELLED',
    'upcoming' => 'NOT_YET_RELEASED',
    _ => null,
  };

  /// Maps MangaBaka `type` onto the AniList-style format vocabulary.
  static String? _mangaBakaFormat(String? type) => switch (type) {
    'manga' => 'MANGA',
    'manhwa' => 'MANHWA',
    'manhua' => 'MANHUA',
    'novel' => 'LIGHT_NOVEL',
    'other' => 'ONE_SHOT',
    _ => null,
  };

  /// Chinese keys on a MangaDex localized map, most specific first: `zh` is
  /// Simplified and `zh-hk` Traditional, and a record may carry either, both
  /// or neither. Shared by the title picker and [_localized].
  static const List<String> _zhTitleKeys = <String>[
    'zh',
    'zh-cn',
    'zh-hans',
    'zh-hk',
    'zh-hant',
  ];

  /// Picks the Chinese value when the map has one, then English, then the
  /// first non-empty value — from a MangaDex localized map (`{en: ..., ja: ...}`).
  /// Tag names only ever ship `en`, so in practice this shifts the description,
  /// and only for the ~7% of records that carry a Chinese one.
  static String? _localized(Object? map) {
    if (map is! Map<String, dynamic>) {
      return map is String ? _nonEmpty(map) : null;
    }
    for (final String lang in _zhTitleKeys) {
      final Object? zh = map[lang];
      if (zh is String && zh.isNotEmpty) return zh;
    }
    final Object? en = map['en'];
    if (en is String && en.isNotEmpty) return en;
    for (final Object? v in map.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static String? _nonEmpty(Object? value) =>
      (value is String && value.isNotEmpty) ? value : null;

  /// Defensive casts for untrusted API JSON: a wrong-shaped field reads as
  /// null instead of throwing.
  static Map<String, dynamic>? _jsonMap(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  static List<dynamic>? _jsonList(Object? value) =>
      value is List<dynamic> ? value : null;

  static String? _jsonString(Object? value) => value is String ? value : null;

  static int? _jsonInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parses a MangaDex `lastChapter` / `lastVolume` number (a possibly-decimal
  /// string like `"700"` or `"215.5"`); empty / unparseable → null.
  static int? _parseCount(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.floor();
  }

  /// Maps MangaDex `status` onto the AniList-style vocabulary.
  static String? _mangaDexStatus(String? status) => switch (status) {
    'ongoing' => 'RELEASING',
    'completed' => 'FINISHED',
    'hiatus' => 'HIATUS',
    'cancelled' => 'CANCELLED',
    _ => null,
  };

  /// Infers a format code from the MangaDex `originalLanguage`.
  static String? _mangaDexFormat(String? language) => switch (language) {
    'ja' => 'MANGA',
    'ko' => 'MANHWA',
    'zh' || 'zh-hk' => 'MANHUA',
    _ => null,
  };

  /// Maps Kitsu manga `subtype` onto the AniList-style format vocabulary.
  static String? _kitsuFormat(String? subtype) => switch (subtype) {
    'manga' => 'MANGA',
    'novel' => 'LIGHT_NOVEL',
    'manhwa' => 'MANHWA',
    'manhua' => 'MANHUA',
    'oneshot' => 'ONE_SHOT',
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
