/// Error from the TapTap web API. [detail] is a redacted, copyable debug
/// string (request + status + body) consumed by `extractApiError`.
class TapTapApiException implements Exception {
  const TapTapApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'TapTapApiException: $message (status: $statusCode)';
}
