import '../api/ximalaya_constants.dart';

/// Field readers for an Ximalaya album row — the only shape this source sees,
/// since the album detail endpoint answers a blacklist page.
int ximalayaAlbumId(Map<String, dynamic> json) =>
    (json['albumId'] as num?)?.toInt() ?? 0;

String? ximalayaTitle(Map<String, dynamic> json) =>
    _nonEmpty(json['title'] as String?);

/// The show notes. Already plain text; no HTML to strip.
String? ximalayaIntro(Map<String, dynamic> json) =>
    _nonEmpty(json['intro'] as String?);

/// The publisher's display name — the anchor, not a studio.
String? ximalayaAnchor(Map<String, dynamic> json) =>
    _nonEmpty(json['nickname'] as String?);

String? ximalayaCoverUrl(Map<String, dynamic> json) {
  final String url = ximalayaCoverUrlFor(json['coverPath'] as String?);
  return url.isEmpty ? null : url;
}

/// `tracksCount` is the episode count; `0` reads as "not filled in", which is
/// not the same as an empty show.
int? ximalayaEpisodeCount(Map<String, dynamic> json) {
  final int? count = (json['tracksCount'] as num?)?.toInt();
  return (count == null || count <= 0) ? null : count;
}

/// `playCount` is a listen total; `0` means nobody has played it, which is a
/// real answer rather than a missing one.
int? ximalayaPlayCount(Map<String, dynamic> json) =>
    (json['playCount'] as num?)?.toInt();

/// `createdAt` is Unix **milliseconds** on this API (unlike `released_time`
/// elsewhere). `updatedAt` is the same unit.
DateTime? ximalayaCreatedAt(Map<String, dynamic> json) {
  final int? millis = (json['createdAt'] as num?)?.toInt();
  if (millis == null || millis <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
