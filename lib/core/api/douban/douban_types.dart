/// Typed Douban error carrying a user-facing [message] and a redacted debug
/// [detail] (consumed by `extractApiError`).
class DoubanApiException implements Exception {
  const DoubanApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'DoubanApiException: $message';
}

final RegExp _isbnStrip = RegExp(r'[\s-]');
final RegExp _isbn13 = RegExp(r'^\d{13}$');
final RegExp _isbn10 = RegExp(r'^\d{9}[\dXx]$');

/// True when [query] is an ISBN-10 or ISBN-13, hyphens and spaces ignored. A
/// bare ten- or thirteen-digit number is long enough not to be a title.
bool isDoubanIsbn(String query) {
  final String clean = normalizeDoubanIsbn(query);
  if (clean.length == 13) return _isbn13.hasMatch(clean);
  if (clean.length == 10) return _isbn10.hasMatch(clean);
  return false;
}

/// The ISBN with its separators removed, ready for the request path.
String normalizeDoubanIsbn(String query) => query.replaceAll(_isbnStrip, '');
