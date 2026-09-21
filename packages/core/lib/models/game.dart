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
    if (json['cover'] != null) {
      final Map<String, dynamic> cover = json['cover'] as Map<String, dynamic>;
      final String? imageId = cover['image_id'] as String?;
      if (imageId != null) {
        // cover_big is 264x374.
        coverUrl = 'https://images.igdb.com/igdb/image/upload/t_cover_big/$imageId.jpg';
      }
    }

    List<String>? genres;
    if (json['genres'] != null) {
      final List<dynamic> genresList = json['genres'] as List<dynamic>;
      genres = genresList
          .map((dynamic g) => (g as Map<String, dynamic>)['name'] as String)
          .toList();
    }

    // Ids only; names are resolved from the platforms table.
    List<int>? platformIds;
    if (json['platforms'] != null) {
      final List<dynamic> platformsList = json['platforms'] as List<dynamic>;
      platformIds = platformsList.map((dynamic p) => p as int).toList();
    }

    DateTime? releaseDate;
    if (json['first_release_date'] != null) {
      releaseDate = DateTime.fromMillisecondsSinceEpoch(
        (json['first_release_date'] as int) * 1000,
      );
    }

    String? artworkUrl;
    if (json['artworks'] != null) {
      final List<dynamic> artworks = json['artworks'] as List<dynamic>;
      if (artworks.isNotEmpty) {
        final Map<String, dynamic> art =
            artworks.first as Map<String, dynamic>;
        final String? artImageId = art['image_id'] as String?;
        if (artImageId != null) {
          artworkUrl =
              'https://images.igdb.com/igdb/image/upload/t_720p/$artImageId.jpg';
        }
      }
    }

    return Game(
      id: json['id'] as int,
      name: json['name'] as String,
      summary: json['summary'] as String?,
      coverUrl: coverUrl,
      releaseDate: releaseDate,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int?,
      genres: genres,
      platformIds: platformIds,
      externalUrl: json['url'] as String?,
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
