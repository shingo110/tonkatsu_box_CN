import 'dart:convert';

import 'package:dio/dio.dart';

import '../../shared/constants/platform_features.dart';
import 'host_rate_limiter.dart';
import 'proxy_rewrite_interceptor.dart';

/// The browser adapter collapses connect and receive into one flat budget, and
/// a proxied call is two hops — 5s aborts an import the server did finish.
const Duration _kWebTimeoutFloor = Duration(seconds: 60);

/// Keyless services (MusicBrainz, Cover Art Archive) throttle or refuse
/// clients without a meaningful User-Agent.
const String kAppUserAgent =
    'TonkatsuBox-CN/1.0 (+https://github.com/shingo110/tonkatsu_box_CN)';

/// The single place every API client gets its [Dio] from — the one seam where
/// the web build routes calls through the selfhost server's proxy.
Dio createApiDio({
  required Duration connectTimeout,
  required Duration receiveTimeout,
  String baseUrl = '',
  Map<String, String>? headers,
  ResponseType responseType = ResponseType.json,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: kIsWebBuild ? _atLeastFloor(connectTimeout) : connectTimeout,
      receiveTimeout: kIsWebBuild ? _atLeastFloor(receiveTimeout) : receiveTimeout,
      // The browser refuses to let a page set User-Agent and logs an error for
      // every request; on web the proxy is the one that sends it anyway.
      headers: kIsWebBuild ? _withoutUserAgent(headers) : headers,
      responseType: responseType,
    ),
  );
  // Before the proxy rewrite, so the queue keys on the real upstream host.
  dio.interceptors.add(HostRateLimitInterceptor());
  // Rewriting the resolved URI covers both shapes in the codebase: a client
  // with a baseUrl and one that builds a full URL per request.
  if (kIsWebBuild) dio.interceptors.add(ProxyRewriteInterceptor());
  return dio;
}

Duration _atLeastFloor(Duration value) =>
    value < _kWebTimeoutFloor ? _kWebTimeoutFloor : value;

/// Reads a body that Dio handed back as a raw String because the provider's
/// `Content-Type` defeats its JSON sniffing — Fantlab sends a trailing `;`,
/// Ximalaya answers `text/plain` for a perfectly good JSON document. Tolerates
/// an already-parsed object (mocks, other transport modes) and returns null
/// for a blank or malformed body.
Object? decodeJsonBody(Object? data) {
  if (data is String) {
    if (data.trim().isEmpty) return null;
    try {
      return jsonDecode(data);
    } on FormatException {
      return null;
    }
  }
  return data;
}

Map<String, String>? _withoutUserAgent(Map<String, String>? headers) {
  if (headers == null) return null;
  return <String, String>{
    for (final MapEntry<String, String> e in headers.entries)
      if (e.key.toLowerCase() != 'user-agent') e.key: e.value,
  };
}
