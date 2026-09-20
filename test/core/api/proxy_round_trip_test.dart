import 'dart:async';

import 'package:core/api/proxy_targets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/proxy_rewrite_interceptor.dart';

/// Runs the interceptor the way Dio would and reports the URI that would leave
/// the browser, without opening a socket.
Future<Uri> rewritten(RequestOptions options) {
  final ProxyRewriteInterceptor interceptor =
      ProxyRewriteInterceptor(baseUrl: 'http://box.lan:8080');
  final Completer<Uri> done = Completer<Uri>();
  interceptor.onRequest(
    options,
    _CapturingHandler((RequestOptions o) => done.complete(o.uri)),
  );
  return done.future;
}

class _CapturingHandler extends RequestInterceptorHandler {
  _CapturingHandler(this.onNext);

  final void Function(RequestOptions) onNext;

  @override
  void next(RequestOptions options) => onNext(options);
}

/// The server half of the contract, reproduced from `ApiProxy.handler`:
/// segment 0 is the `/proxy` prefix, segment 1 the slug, the rest the upstream
/// path. Kept here so the two tiers are checked against each other — a rewrite
/// that agrees with nothing on the other side is the failure this guards.
Uri upstreamOf(Uri proxied) {
  final List<String> segments = proxied.pathSegments;
  return Uri(
    scheme: 'https',
    host: proxyTargetForSlug(segments[1])!.host,
    pathSegments: segments.skip(2),
    queryParameters: proxied.queryParametersAll.isEmpty
        ? null
        : proxied.queryParametersAll,
  );
}

void main() {
  group('proxy target allowlist', () {
    test('should resolve every host and slug back to the same target', () {
      for (final ProxyTarget target in ProxyTarget.values) {
        expect(proxyTargetForHost(target.host), target, reason: target.host);
        expect(proxyTargetForSlug(target.slug), target, reason: target.slug);
      }
    });

    test('should resolve a host regardless of case', () {
      expect(proxyTargetForHost('API.BGM.TV'), ProxyTarget.bangumi);
    });

    test('should give every target a host and a slug of its own', () {
      expect(
        ProxyTarget.values.map((ProxyTarget t) => t.host).toSet(),
        hasLength(ProxyTarget.values.length),
      );
      expect(
        ProxyTarget.values.map((ProxyTarget t) => t.slug).toSet(),
        hasLength(ProxyTarget.values.length),
      );
    });

    test('should reject anything off the allowlist', () {
      expect(proxyTargetForHost('evil.example'), isNull);
      expect(proxyTargetForSlug('evil.example'), isNull);
    });
  });

  group('client rewrite meets server rebuild', () {
    test('should come back as the same upstream URL for every target',
        () async {
      for (final ProxyTarget target in ProxyTarget.values) {
        final Uri original = Uri.parse(
          'https://${target.host}/v1/things/42?q=a&q=b&page=2',
        );

        final Uri rebuilt = upstreamOf(
          await rewritten(RequestOptions(path: original.toString())),
        );

        expect(rebuilt.host, original.host, reason: target.slug);
        expect(rebuilt.path, original.path, reason: target.slug);
        expect(
          rebuilt.queryParametersAll,
          original.queryParametersAll,
          reason: target.slug,
        );
      }
    });

    test('should keep both values of a repeated query parameter', () async {
      final Uri rebuilt = upstreamOf(await rewritten(
        RequestOptions(path: 'https://api.tvmaze.com/search/shows?q=a&q=b'),
      ));

      expect(rebuilt.queryParametersAll['q'], <String>['a', 'b']);
    });

    test('should carry a percent-encoded value across both tiers', () async {
      final Uri rebuilt = upstreamOf(await rewritten(RequestOptions(
        path: 'https://api.bgm.tv/v0/subjects'
            '?name=%E6%B5%B7%E8%B4%BC%E7%8E%8B%20ONE%20PIECE',
      )));

      expect(rebuilt.queryParameters['name'], '海贼王 ONE PIECE');
    });

    test('should handle a bare host, which is where AniList posts', () async {
      final Uri rebuilt = upstreamOf(
        await rewritten(RequestOptions(path: 'https://graphql.anilist.co')),
      );

      expect(rebuilt.host, 'graphql.anilist.co');
      expect(rebuilt.path, isEmpty);
    });
  });
}
