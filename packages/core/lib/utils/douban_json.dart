/// Parsing helpers for Douban movie and TV records (frodo.douban.com). A
/// `/api/v2/search/movie` row carries a thin `target`; `/api/v2/movie/{id}` and
/// `/api/v2/tv/{id}` answer with the same 73-field record. Both shapes go
/// through these helpers, so movie and TV mappings cannot drift apart.
///
/// Beware the search endpoint: it is one mixed pool of films and series and
/// its `type` parameter is ignored, so the row's `target_type` is the only
/// thing that tells the two apart.
library;

/// Numeric subject id. Douban mints ids as decimal strings; a row without one
/// cannot key a cache entry.
int doubanItemId(Map<String, dynamic> json) {
  final Object? raw = json['id'];
  if (raw is int) return raw;
  final int? parsed = raw is String ? int.tryParse(raw.trim()) : null;
  if (parsed == null) {
    throw const FormatException('Douban item without a numeric id');
  }
  return parsed;
}

/// Chinese title. Douban answers in Chinese, so this is the display name.
String? doubanItemTitle(Map<String, dynamic> json) => _nonEmpty(json['title']);

/// Native title. Douban leaves this empty on its Chinese film records but
/// fills it with the Japanese name on an animation, so this is the only place
/// an anime's original title can come from.
String? doubanItemNativeTitle(Map<String, dynamic> json) =>
    _nonEmpty(json['original_title']);

/// The first Latin-script alias in `aka` — Douban's English spelling. A Chinese
/// alias can still carry Latin letters ("流浪地球2(3D版)"), so an alias with Han
/// characters is not an English title and is skipped.
String? doubanItemAliasTitle(Map<String, dynamic> json) {
  final Object? aka = json['aka'];
  if (aka is! List<dynamic>) return null;
  final String? title = doubanItemTitle(json);
  for (final Object? entry in aka) {
    final String? value = _nonEmpty(entry);
    if (value == null || value == title) continue;
    if (!RegExp('[A-Za-z]').hasMatch(value)) continue;
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(value)) continue;
    return value;
  }
  return null;
}

/// Original title: the field Douban states when it has one, the Latin alias
/// otherwise.
String? doubanItemOriginalTitle(Map<String, dynamic> json) =>
    doubanItemNativeTitle(json) ?? doubanItemAliasTitle(json);

/// Poster. Full records prefer `pic.large`; search rows only carry `cover_url`.
String? doubanItemCoverUrl(Map<String, dynamic> json) {
  final Object? pic = json['pic'];
  if (pic is Map<String, dynamic>) {
    final String? large = _nonEmpty(pic['large']);
    if (large != null) return large;
  }
  return _nonEmpty(json['cover_url']);
}

/// Synopsis. Full records carry `intro`; a search row's `abstract` is always
/// empty, so a row's overview stays null until the detail call fills it in.
String? doubanItemOverview(Map<String, dynamic> json) =>
    _nonEmpty(json['intro']) ?? _nonEmpty(json['abstract']);

/// Genres. Full records ship a `genres` array; a search row only folds them
/// into `card_subtitle`, whose second segment is the space-joined genre list.
List<String> doubanItemGenres(Map<String, dynamic> json) {
  final Object? raw = json['genres'];
  if (raw is List<dynamic>) {
    final List<String> listed = <String>[];
    for (final Object? genre in raw) {
      final String? value = _nonEmpty(genre);
      if (value != null) listed.add(value);
    }
    if (listed.isNotEmpty) return listed;
  }

  final List<String> parts = doubanSubtitleParts(json);
  // The two shapes spell `card_subtitle` differently — a search row leads with
  // the country, a full record with the year — so the genre slot follows.
  final int slot = (parts.isNotEmpty && _isYear(parts.first)) ? 2 : 1;
  if (parts.length <= slot) return const <String>[];
  return parts[slot]
      .split(' ')
      .map((String genre) => genre.trim())
      .where((String genre) => genre.isNotEmpty)
      .toList();
}

/// `card_subtitle` is a " / "-joined line. Movies and TV spell it
/// "country / genre / director / cast", unlike books' "author / year /
/// publisher", so the segments are positional.
List<String> doubanSubtitleParts(Map<String, dynamic> json) {
  final String? raw = _nonEmpty(json['card_subtitle']);
  if (raw == null) return const <String>[];
  return raw
      .split('/')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList();
}

/// Release year. Douban sends it as a string on both shapes and as an empty
/// one for unreleased titles.
int? doubanItemYear(Map<String, dynamic> json) {
  final Object? raw = json['year'];
  final int? parsed =
      raw is int ? raw : (raw is String ? int.tryParse(raw.trim()) : null);
  if (parsed == null || parsed < 1800 || parsed > 2099) return null;
  return parsed;
}

/// Already on the app's 0–10 scale. Douban's `rating.value` is not out of
/// five, so doubling it would be wrong.
double? doubanItemRating(Map<String, dynamic> json) {
  final Object? raw = json['rating'];
  if (raw is! Map<String, dynamic>) return null;
  final Object? value = raw['value'];
  if (value is! num || value <= 0) return null;
  return value.toDouble();
}

/// Runtime in minutes. Full records list `durations: ["173分钟"]`; a search row
/// carries none, so a row's runtime stays null.
int? doubanRuntimeMinutes(Map<String, dynamic> json) {
  final Object? raw = json['durations'];
  if (raw is! List<dynamic> || raw.isEmpty) return null;
  final Object? first = raw.first;
  if (first is! String) return null;
  final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(first);
  if (match == null) return null;
  final int? minutes = int.tryParse(match.group(1)!);
  if (minutes == null || minutes <= 0) return null;
  return minutes;
}

/// Episodes on a series record. Douban files a series as one subject with no
/// season split, so this is the whole run; movies answer 0.
int? doubanEpisodeCount(Map<String, dynamic> json) {
  final Object? raw = json['episodes_count'];
  if (raw is! num) return null;
  final int value = raw.toInt();
  return value > 0 ? value : null;
}

/// Votes behind the score. Douban counts ratings rather than list adds, which
/// is the nearest thing it offers to a popularity figure.
int? doubanRatingCount(Map<String, dynamic> json) {
  final Object? raw = json['rating'];
  if (raw is! Map<String, dynamic>) return null;
  final Object? count = raw['count'];
  if (count is! num || count <= 0) return null;
  return count.toInt();
}

/// Whether a record is a film or a series. A full record states it in `type`;
/// a search row's thin `target` only spells it out in its `douban:///tv/{id}`
/// uri, so both shapes are read.
String? doubanSubjectKind(Map<String, dynamic> json) {
  final String? type = _nonEmpty(json['type']) ?? _nonEmpty(json['subtype']);
  if (type == 'movie' || type == 'tv') return type;
  final String? uri = _nonEmpty(json['uri']);
  if (uri == null) return null;
  if (uri.contains('/tv/')) return 'tv';
  if (uri.contains('/movie/')) return 'movie';
  return null;
}

/// An animation. Douban files them among films and series rather than under a
/// subject type of their own, so the genre list is the only marker.
bool doubanIsAnimation(Map<String, dynamic> json) =>
    doubanItemGenres(json).contains('动画');

/// Public page. Records carry a `douban://douban.com/...` uri rather than an
/// https link, so the address is rebuilt from the id.
String doubanItemUrl(Map<String, dynamic> json) =>
    'https://movie.douban.com/subject/${doubanItemId(json)}';

/// Music artists. A full record lists them in `singer`; a search row only folds
/// the lead credit into `card_subtitle`, which for music spells it
/// "artist / year" — the opposite order from the film pool.
List<String> doubanMusicArtists(Map<String, dynamic> json) {
  final Object? singer = json['singer'];
  if (singer is List<dynamic>) {
    final List<String> names = <String>[];
    for (final Object? entry in singer) {
      final String? name = entry is Map<String, dynamic>
          ? _nonEmpty(entry['name'])
          : _nonEmpty(entry);
      if (name != null) names.add(name);
    }
    if (names.isNotEmpty) return names;
  }

  final List<String> parts = doubanSubtitleParts(json);
  if (parts.isNotEmpty && !_isYear(parts.first)) return <String>[parts.first];
  return const <String>[];
}

/// Release date. A full record sends `pubdate` as a list and spells it as
/// loosely as Douban stores it ("2000", "2011-07", "2006-1-30"); a search row
/// carries only the trailing year of `card_subtitle`.
String? doubanMusicFirstReleaseDate(Map<String, dynamic> json) {
  final Object? pubdate = json['pubdate'];
  if (pubdate is List<dynamic>) {
    for (final Object? entry in pubdate) {
      final String? value = _nonEmpty(entry);
      if (value != null) return value;
    }
  }
  final String? single = _nonEmpty(pubdate);
  if (single != null) return single;

  final List<String> parts = doubanSubtitleParts(json);
  if (parts.length > 1 && _isYear(parts.last)) return parts.last;
  return null;
}

/// Release year, from the leading four digits of the release date. Douban
/// sends a year-only `pubdate` on most records, so this is usually the whole
/// value.
int? doubanMusicYear(Map<String, dynamic> json) {
  final String? date = doubanMusicFirstReleaseDate(json);
  if (date == null || date.length < 4) return null;
  final int? year = int.tryParse(date.substring(0, 4));
  if (year == null || year < 1800 || year > 2099) return null;
  return year;
}

/// Genres. Only a full record carries them; a search row's `card_subtitle`
/// holds an artist and a year for music, so nothing there can be read as a
/// genre — unlike the film pool, where the genre list is a subtitle segment.
List<String> doubanMusicGenres(Map<String, dynamic> json) {
  final Object? raw = json['genres'];
  if (raw is! List<dynamic>) return const <String>[];
  final List<String> genres = <String>[];
  for (final Object? entry in raw) {
    final String? value = _nonEmpty(entry);
    if (value != null) genres.add(value);
  }
  return genres;
}

/// Label / publisher. Always a list on a full record, and a single entry often
/// names several imprints already ("吉林音像出版社，厦门标旗文化").
String? doubanMusicLabel(Map<String, dynamic> json) {
  final Object? publisher = json['publisher'];
  if (publisher is List<dynamic>) {
    for (final Object? entry in publisher) {
      final String? value = _nonEmpty(entry);
      if (value != null) return value;
    }
    return null;
  }
  return _nonEmpty(publisher);
}

/// Medium of the release — "CD", "黑胶". A full record lists `media`.
String? doubanMusicFormat(Map<String, dynamic> json) {
  final Object? media = json['media'];
  if (media is List<dynamic>) {
    for (final Object? entry in media) {
      final String? value = _nonEmpty(entry);
      if (value != null) return value;
    }
    return null;
  }
  return _nonEmpty(media);
}

/// Disc count. `discs` lists one entry per disc, and is empty on records that
/// never said.
int? doubanMusicDiscCount(Map<String, dynamic> json) {
  final Object? discs = json['discs'];
  if (discs is! List<dynamic>) return null;
  int count = 0;
  for (final Object? disc in discs) {
    if (_nonEmpty(disc) != null) count++;
  }
  return count > 0 ? count : null;
}

/// A full record's track list. Rows without a `track_number` are section
/// headers, not tracks — a user-built compilation interleaves "全套曲目",
/// "CD1", "早期音乐" and "总时间：70分钟" between the real entries — so they are
/// dropped here. Douban numbers tracks across the whole release rather than
/// per disc, so the surviving numbers are unique.
List<Map<String, dynamic>> doubanMusicSongs(Map<String, dynamic> json) {
  final Object? songs = json['songs'];
  if (songs is! List<dynamic>) return const <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> tracks = <Map<String, dynamic>>[];
  for (final Object? entry in songs) {
    if (entry is! Map<String, dynamic>) continue;
    if (entry['track_number'] is! num) continue;
    if (_nonEmpty(entry['title']) == null) continue;
    tracks.add(entry);
  }
  return tracks;
}

/// Track count. Only the detail call carries a list, so a search row reports
/// none until it is refreshed.
int? doubanMusicTrackCount(Map<String, dynamic> json) {
  final int count = doubanMusicSongs(json).length;
  return count > 0 ? count : null;
}

/// A track title with its length. Douban's `duration` field is zero on every
/// row, but a user-built compilation spells "3:46" at the end of the title
/// instead; an official list carries no length at all.
({String title, int? lengthMs}) doubanTrackTitleAndLength(Object? raw) {
  final String value = raw is String ? raw.trim() : '';
  final RegExpMatch? match =
      RegExp(r'^(.*?)\s+(\d{1,3}):([0-5]\d)$').firstMatch(value);
  if (match == null) return (title: value, lengthMs: null);
  final int minutes = int.parse(match.group(2)!);
  final int seconds = int.parse(match.group(3)!);
  return (
    title: match.group(1)!.trim(),
    lengthMs: ((minutes * 60) + seconds) * 1000,
  );
}

/// Public page. A full record states `url` outright — and on its own host,
/// `music.douban.com` rather than the film one — while a search row's `uri` is
/// a `douban://` address, so the page is rebuilt from the id.
String doubanMusicUrl(Map<String, dynamic> json) {
  final String? stated = _nonEmpty(json['url']);
  if (stated != null) return stated;
  return 'https://music.douban.com/subject/${doubanItemId(json)}/';
}

String? _nonEmpty(Object? raw) {
  if (raw is! String) return null;
  final String value = raw.trim();
  return value.isEmpty ? null : value;
}

bool _isYear(String value) =>
    value.length == 4 && int.tryParse(value) != null;
