/// NeoDB's catalog category for books. The detail path reuses the category as
/// its own prefix (`/api/book/{uuid}`), so one constant drives both calls.
const String kNeoDBBookCategory = 'book';

/// Error from the NeoDB API. [detail] is a redacted, copyable debug
/// string (request + status + body) consumed by `extractApiError`.
class NeoDBApiException implements Exception {
  const NeoDBApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'NeoDBApiException: $message (status: $statusCode)';
}
