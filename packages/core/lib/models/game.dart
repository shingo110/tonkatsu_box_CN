import '../api/taptap_constants.dart';
import '../utils/taptap_json.dart';
import 'game_time_to_beat.dart';

class Game {
  const Game({
    required this.id,
    required this.name,
    this.summary,
    this.coverUrl,
    this.releaseDate,
    this.rating,
    this.ratingCount,
    this.genres,
    this.platformIds,
    this.externalUrl,
    this.cachedAt,
    this.artworkUrl,
    this.timeToBeat,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    String? coverUrl;
    final Map<String, dynamic>? cover = _jsonMap(json['cover']);
    final String? imageId = _jsonString(cover?['image_id']);
    if (imageId != null) {
      // cover_big is 264x374.
      coverUrl =
          'https://images.igdb.com/igdb/image/upload/t_cover_big/$imageId.jpg';
    }

    // Genre entries arrive as `{name}` objects; a wrong-shaped one is dropped
    // rather than thrown out of the parse.
    List<String>? genres;
    final List<dynamic>? genresList = _jsonList(json['genres']);
    if (genresList != null && genresList.isNotEmpty) {
      genres = genresList
          .map((Object? g) {
            final Map<String, dynamic>? entry = _jsonMap(g);
            return entry == null ? null : _jsonString(entry['name']);
          })
          .whereType<String>()
          .toList();
      if (genres.isEmpty) genres = null;
    }

    // Ids only; names are resolved from the platforms table. Accepts
    // List<int>, List<num>, List<Map{'id':?}> and List<String> — IGDB has
    // drifted between these shapes.
    List<int>? platformIds;
    final Object? rawPlatforms = json['platforms'];
    if (rawPlatforms is List) {
      final List<int> parsed = <int>[];
      for (final Object? p in rawPlatforms) {
        if (p is int) {
          parsed.add(p);
        } else if (p is num) {
          parsed.add(p.toInt());
        } else if (p is Map) {
          final Object? id = p['id'];
          if (id is num) {
            parsed.add(id.toInt());
          } else if (id is String) {
            final int? v = int.tryParse(id);
            if (v != null && v >= 0) parsed.add(v);
          }
        } else if (p is String) {
          final int? v = int.tryParse(p);
          if (v != null && v >= 0) parsed.add(v);
        }
      }
      platformIds = parsed;
    }

    DateTime? releaseDate;
    final Object? rawReleaseDate = json['first_release_date'];
    if (rawReleaseDate != null) {
      final int? epochSeconds = rawReleaseDate is num
          ? rawReleaseDate.toInt()
          : rawReleaseDate is String
          ? int.tryParse(rawReleaseDate)
          : null;
      if (epochSeconds != null) {
        releaseDate = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
      }
    }

    String? artworkUrl;
    final List<dynamic>? artworks = _jsonList(json['artworks']);
    if (artworks != null && artworks.isNotEmpty) {
      final Map<String, dynamic>? art = _jsonMap(artworks.first);
      final String? artImageId = _jsonString(art?['image_id']);
      if (artImageId != null) {
        artworkUrl =
            'https://images.igdb.com/igdb/image/upload/t_720p/$artImageId.jpg';
      }
    }

    return Game(
      // Lenient on purpose: an IGDB page is mapped with no per-row catch,
      // so throwing on a drifted id would lose the whole result set.
      id: _jsonInt(json['id']) ?? 0,
      name: _jsonString(json['name']) ?? 'Unknown',
      summary: _jsonString(json['summary']),
      coverUrl: coverUrl,
      releaseDate: releaseDate,
      rating: _ratingFromJson(json['rating']),
      ratingCount: _jsonInt(json['rating_count']),
      genres: genres,
      platformIds: platformIds,
      externalUrl: _jsonString(json['url']),
      cachedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      artworkUrl: artworkUrl,
    );
  }

  /// From a TapTap app record — `/webapiv2/app-search/v1/by-keyword` rows and
  /// `/webapiv2/app/v4/detail` records share every key read here.
  ///
  /// TapTap has no platform table and no English name: a mainland app store
  /// lists one Android / iOS build, so `platformIds` stays null and the picker
  /// adds the game straight away. The title slot takes TapTap's Chinese name,
  /// which is the only name it carries.
  factory Game.fromTapTap(Map<String, dynamic> json) {
    final int appId = taptapAppId(json);
    return Game(
      // Shifted so the id cannot collide with an IGDB id — see
      // [kTapTapIdOffset]; the refresh path shifts it back.
      id: appId + kTapTapIdOffset,
      name: taptapTitle(json) ?? 'Unknown',
      summary: taptapDescription(json),
      coverUrl: taptapIconUrl(json),
      releaseDate: taptapReleaseDate(json),
      rating: taptapRating(json),
      ratingCount: taptapRatingCount(json),
      genres: taptapGenres(json),
      platformIds: null,
      externalUrl: tapTapAppUrl(appId),
      cachedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      artworkUrl: taptapArtworkUrl(json),
    );
  }

  factory Game.fromDb(Map<String, dynamic> row) {
    List<String>? genres;
    if (row['genres'] != null && (row['genres'] as String).isNotEmpty) {
      genres = (row['genres'] as String).split('|');
    }

    List<int>? platformIds;
    if (row['platform_ids'] != null &&
        (row['platform_ids'] as String).isNotEmpty) {
      platformIds = (row['platform_ids'] as String)
          .split(',')
          .map((String s) => int.parse(s))
          .toList();
    }

    DateTime? releaseDate;
    if (row['release_date'] != null) {
      releaseDate = DateTime.fromMillisecondsSinceEpoch(
        (row['release_date'] as int) * 1000,
      );
    }

    return Game(
      id: row['id'] as int,
      name: row['name'] as String,
      summary: row['summary'] as String?,
      coverUrl: row['cover_url'] as String?,
      releaseDate: releaseDate,
      rating: row['rating'] as double?,
      ratingCount: row['rating_count'] as int?,
      genres: genres,
      platformIds: platformIds,
      externalUrl: row['external_url'] as String?,
      cachedAt: row['cached_at'] as int?,
      artworkUrl: row['artwork_url'] as String?,
    );
  }

  final int id;

  final String name;

  final String? summary;

  final String? coverUrl;

  final DateTime? releaseDate;

  /// IGDB scale is 0–100; [formattedRating] converts to 0–10.
  final double? rating;

  final int? ratingCount;

  final List<String>? genres;

  final List<int>? platformIds;

  final String? externalUrl;

  /// Cache timestamp, Unix seconds.
  final int? cachedAt;

  final String? artworkUrl;

  /// Transient: fetched with search, never stored — excluded from [toDb] /
  /// [fromDb] / [fromJson].
  final GameTimeToBeat? timeToBeat;

  /// IGDB has returned `rating` as num and (rarely) as a string; both are
  /// accepted, anything else reads as null.
  static double? _ratingFromJson(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Defensive casts for untrusted API JSON: a wrong-shaped field reads as
  /// null instead of throwing. Mirrors `Anime` / `Manga`.
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

  int? get releaseYear => releaseDate?.year;

  /// True when this record came from TapTap. The model carries no source
  /// column, but TapTap ids are shifted out of IGDB's range, so the id itself
  /// says which catalogue minted it — see [kTapTapIdOffset].
  bool get isFromTapTap => id >= kTapTapIdOffset;

  /// The bare TapTap app id, or null for an IGDB record.
  int? get tapTapAppId => isFromTapTap ? id - kTapTapIdOffset : null;

  String? get formattedRating {
    if (rating == null) return null;
    return (rating! / 10).toStringAsFixed(1);
  }

  String? get genresString => genres?.join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Game && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Game(id: $id, name: $name)';

  Map<String, dynamic> toDb() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'summary': summary,
      'cover_url': coverUrl,
      'release_date': releaseDate != null
          ? releaseDate!.millisecondsSinceEpoch ~/ 1000
          : null,
      'rating': rating,
      'rating_count': ratingCount,
      'genres': genres?.join('|'),
      'platform_ids': platformIds?.join(','),
      'external_url': externalUrl,
      'cached_at': cachedAt,
      'artwork_url': artworkUrl,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'summary': summary,
      'cover_url': coverUrl,
      'release_date': releaseDate != null
          ? releaseDate!.millisecondsSinceEpoch ~/ 1000
          : null,
      'rating': rating,
      'rating_count': ratingCount,
      'genres': genres,
      'platform_ids': platformIds,
      'external_url': externalUrl,
    };
  }

  Game copyWith({
    int? id,
    String? name,
    String? summary,
    String? coverUrl,
    DateTime? releaseDate,
    double? rating,
    int? ratingCount,
    List<String>? genres,
    List<int>? platformIds,
    String? externalUrl,
    int? cachedAt,
    String? artworkUrl,
    GameTimeToBeat? timeToBeat,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      coverUrl: coverUrl ?? this.coverUrl,
      releaseDate: releaseDate ?? this.releaseDate,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      genres: genres ?? this.genres,
      platformIds: platformIds ?? this.platformIds,
      externalUrl: externalUrl ?? this.externalUrl,
      cachedAt: cachedAt ?? this.cachedAt,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      timeToBeat: timeToBeat ?? this.timeToBeat,
    );
  }
}
