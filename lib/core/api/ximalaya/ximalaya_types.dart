/// Error from the Ximalaya web API. [detail] is a redacted, copyable debug
/// string (request + status + body) consumed by `extractApiError`.
class XimalayaApiException implements Exception {
  const XimalayaApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'XimalayaApiException: $message (status: $statusCode)';
}
