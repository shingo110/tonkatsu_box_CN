import '../api/taptap_constants.dart';
import 'html_text.dart';

/// Field readers for the TapTap app payload. A search row and a detail record
/// share the same keys, so one set of readers serves both shapes.

/// Bare app id, as TapTap knows it. [Game.id] stores it shifted — see
/// [kTapTapIdOffset].
int taptapAppId(Map<String, dynamic> json) =>
    (json['id'] as num?)?.toInt() ?? 0;

String? taptapTitle(Map<String, dynamic> json) =>
    _nonEmpty(json['title'] as String?);

/// Chinese name is the only name TapTap carries; it goes in the display slot.
String? taptapDescription(Map<String, dynamic> json) {
  final Object? description = json['description'];
  if (description is! Map<String, dynamic>) return null;
  return stripHtmlText(description['text'] as String?);
}

/// Square app icon — the shape the grid expects.
String? taptapIconUrl(Map<String, dynamic> json) =>
    _imageUrl(json['icon'], preferMedium: true);

/// Wide banner art, used as the backdrop rather than the cover.
String? taptapArtworkUrl(Map<String, dynamic> json) =>
    _imageUrl(json['cover']) ?? _imageUrl(json['banner']);

/// TapTap's community score on a 0–10 scale; [Game.rating] is 0–100.
double? taptapRating(Map<String, dynamic> json) {
  final Object? stat = json['stat'];
  if (stat is! Map<String, dynamic>) return null;
  final Object? rating = stat['rating'];
  if (rating is! Map<String, dynamic>) return null;
  // The score arrives as a string ("7.9") and is absent on unreleased apps.
  final String? raw = _nonEmpty(rating['score'] as String?);
  final double? score = raw == null ? null : double.tryParse(raw);
  return score == null ? null : score * 10;
}

/// Total votes across the five buckets of `vote_info`. The API reports no
/// single count, and a score with no votes to back it is not worth showing.
int? taptapRatingCount(Map<String, dynamic> json) {
  final Object? stat = json['stat'];
  if (stat is! Map<String, dynamic>) return null;
  final Object? votes = stat['vote_info'];
  if (votes is! Map<String, dynamic>) return null;
  int total = 0;
  for (final Object? value in votes.values) {
    total += (value as num?)?.toInt() ?? 0;
  }
  return total == 0 ? null : total;
}

/// Chinese community tags, in TapTap's own order, capped so a heavily tagged
/// app cannot flood the row.
List<String> taptapGenres(Map<String, dynamic> json, {int max = 12}) {
  final Object? tags = json['tags'];
  if (tags is! List<dynamic>) return const <String>[];
  final List<String> values = <String>[];
  for (final Object? entry in tags) {
    if (entry is! Map<String, dynamic>) continue;
    final String? value = _nonEmpty(entry['value'] as String?);
    if (value != null) values.add(value);
  }
  return values.length > max ? values.sublist(0, max) : values;
}

/// The developer, taken from the labelled `developers` entry rather than from
/// the detail record's free-form `information` block.
String? taptapStudio(Map<String, dynamic> json) {
  final Object? developers = json['developers'];
  if (developers is! List<dynamic>) return null;
  for (final Object? entry in developers) {
    if (entry is! Map<String, dynamic>) continue;
    final String? name = _nonEmpty(entry['name'] as String?);
    if (name != null) return name;
  }
  return null;
}

/// `released_time` is Unix seconds and reads 0 for an unreleased app.
DateTime? taptapReleaseDate(Map<String, dynamic> json) {
  final int? seconds = (json['released_time'] as num?)?.toInt();
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

/// `{url, medium_url, small_url, original_url}` — the size variants are
/// suffixed copies of the same file.
String? _imageUrl(Object? image, {bool preferMedium = false}) {
  if (image is! Map<String, dynamic>) return null;
  final String? medium = _nonEmpty(image['medium_url'] as String?);
  final String? plain = _nonEmpty(image['url'] as String?);
  if (preferMedium) return medium ?? plain;
  return plain ?? medium;
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
