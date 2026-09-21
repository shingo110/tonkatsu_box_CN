import 'dart:convert';
import 'dart:io';

import 'package:core/api/douban_constants.dart';
import 'package:core/api/psn_constants.dart';
import 'package:core/api/taptap_constants.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tonkatsu_server/src/api_credentials.dart';
import 'package:tonkatsu_server/src/app_handler.dart';
import 'package:tonkatsu_server/src/douban_defaults.dart';
import 'package:tonkatsu_server/src/proxy_handler.dart';
import 'package:tonkatsu_server/src/upstream_client.dart';

/// Records what the proxy decided to send and answers from a script.
class _FakeUpstream implements UpstreamClient {
  _FakeUpstream([this.script = const <UpstreamResponse>[]]);

  final List<UpstreamResponse> script;
  final List<({String method, Uri url, Map<String, String> headers, String body})>
      sent =
      <({String method, Uri url, Map<String, String> headers, String body})>[];

  @override
  Future<UpstreamResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<int>? body,
  }) async {
    sent.add((
      method: method,
      url: url,
      headers: Map<String, String>.from(headers),
      body: body == null ? '' : utf8.decode(body),
    ));
    if (sent.length <= script.length) return script[sent.length - 1];
    return const UpstreamResponse(
      status: 200,
      contentType: 'application/json',
      body: <int>[],
    );
  }
}

UpstreamResponse _json(Object? payload, {int status = 200}) => UpstreamResponse(
      status: status,
      contentType: 'application/json',
      body: utf8.encode(jsonEncode(payload)),
    );

void main() {
  late _FakeUpstream upstream;

  Handler handlerWith(
    Map<String, String> keys, {
    List<UpstreamResponse> script = const <UpstreamResponse>[],
    DateTime Function()? clock,
  }) {
    upstream = _FakeUpstream(script);
    return buildAppHandler(
      schemaVersion: 1,
      proxy: ApiProxy(
        credentials: ApiCredentials(keys),
        upstream: upstream,
        clock: clock,
      ),
      logger: (Handler inner) => inner,
    );
  }

  Future<Response> get(Handler handler, String path) async =>
      handler(Request('GET', Uri.parse('http://localhost$path')));

  group('GET /proxy/<slug>/<path>', () {
    test('should forward to the allowlisted host, path and query intact',
        () async {
      final Handler handler = handlerWith(<String, String>{});

      await get(handler, '/proxy/anilist/graphql?q=naruto&page=2');

      expect(upstream.sent.single.url.host, 'graphql.anilist.co');
      expect(upstream.sent.single.url.path, '/graphql');
      expect(upstream.sent.single.url.queryParameters, <String, String>{
        'q': 'naruto',
        'page': '2',
      });
    });

    test('should keep every value of a repeated query parameter', () async {
      final Handler handler = handlerWith(<String, String>{});

      await get(handler, '/proxy/tvmaze/search?q=a&q=b');

      expect(
        upstream.sent.single.url.queryParametersAll['q'],
        <String>['a', 'b'],
      );
    });

    test('should send a User-Agent the browser could not', () async {
      final Handler handler = handlerWith(<String, String>{});

      await get(handler, '/proxy/anilist/graphql');

      expect(
        upstream.sent.single.headers[HttpHeaders.userAgentHeader],
        kProxyUserAgent,
      );
    });

    test('should send TapTap the X-UA header the contract names', () async {
      // X-UA is not on the forwarded list, so without this the upstream gets
      // 400 INVALID_XUA and the games tab opens empty on the web build.
      final Handler handler = handlerWith(<String, String>{});

      await get(handler, '/proxy/taptap/webapiv2/app-search/v1/by-keyword?kw=x');

      expect(upstream.sent.single.headers['X-UA'], kTapTapXUa);
    });

    test('should ignore a caller-supplied X-UA in favour of the contract one',
        () async {
      final Handler handler = handlerWith(<String, String>{});

      await handler(Request(
        'GET',
        Uri.parse('http://localhost/proxy/taptap/webapiv2/app/v4/detail?id=1'),
        headers: <String, String>{'X-UA': 'V=1&PN=SomebodyElse'},
      ));

      expect(upstream.sent.single.headers['X-UA'], kTapTapXUa);
    });

    test('should refuse a host that is not on the allowlist', () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response = await get(handler, '/proxy/evil.example/steal');

      expect(response.statusCode, HttpStatus.notFound);
      expect(upstream.sent, isEmpty);
    });

    test('should pass the upstream status and body back unchanged', () async {
      final Handler handler = handlerWith(
        <String, String>{},
        script: <UpstreamResponse>[
          _json(<String, Object?>{'data': 42}, status: 418),
        ],
      );

      final Response response = await get(handler, '/proxy/anilist/graphql');

      expect(response.statusCode, 418);
      expect(jsonDecode(await response.readAsString()), <String, Object?>{
        'data': 42,
      });
    });

    test('should not let a caller pass its own Authorization through',
        () async {
      final Handler handler = handlerWith(<String, String>{});

      await handler(Request(
        'GET',
        Uri.parse('http://localhost/proxy/anilist/graphql'),
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer stolen',
        },
      ));

      expect(
        upstream.sent.single.headers[HttpHeaders.authorizationHeader],
        isNull,
      );
    });
  });

  group('credential injection', () {
    test('should move an NPSSO query parameter into the PSN Cookie header',
        () async {
      // A browser refuses to set Cookie, and the proxy forwards only
      // content-type and accept — so the web client carries the NPSSO in the
      // URL and the server puts it back where Sony expects it.
      final Handler handler = handlerWith(<String, String>{});

      final Response response = await get(
        handler,
        '/proxy/psnauth/api/authz/v3/oauth/authorize'
        '?npsso=my-npsso&client_id=09515159-7237-4370-9b40-3806e67c0891',
      );

      expect(response.statusCode, HttpStatus.ok);
      final ({String method, Uri url, Map<String, String> headers, String body})
          sent = upstream.sent.single;
      expect(sent.url.host, 'ca.account.sony.com');
      expect(sent.headers[HttpHeaders.cookieHeader], 'npsso=my-npsso');
      expect(sent.headers[HttpHeaders.authorizationHeader], kPsnBasicAuth);
      // Stripped, so a password-equivalent value never travels upstream as a
      // URL or lands in Sony's access log.
      expect(sent.url.queryParameters.containsKey(kPsnNpssoParam), isFalse);
      expect(sent.url.queryParameters['client_id'],
          '09515159-7237-4370-9b40-3806e67c0891');
    });

    test('should still send the PSN client pair when no NPSSO is supplied',
        () async {
      // The sign-in page request carries no credential of its own, but the
      // token exchange always needs the pair.
      final Handler handler = handlerWith(<String, String>{});

      await get(handler, '/proxy/psnauth/api/authz/v3/oauth/token');

      expect(upstream.sent.single.headers[HttpHeaders.authorizationHeader],
          kPsnBasicAuth);
    });

    test('should move a PSN access token into the Authorization header',
        () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response = await get(
        handler,
        '/proxy/psnweb/api/graphql/v1/op'
        '?operationName=getPurchasedGameList&access_token=a-jwt',
      );

      expect(response.statusCode, HttpStatus.ok);
      final ({String method, Uri url, Map<String, String> headers, String body})
          sent = upstream.sent.single;
      expect(sent.url.host, 'web.np.playstation.com');
      expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer a-jwt');
      expect(
        sent.url.queryParameters.containsKey(kPsnAccessTokenParam),
        isFalse,
      );
      expect(sent.url.queryParameters['operationName'], 'getPurchasedGameList');
    });

    test('should add the TMDB key as a query parameter', () async {
      final Handler handler =
          handlerWith(<String, String>{CredentialNames.tmdb: 'tmdb-secret'});

      await get(handler, '/proxy/tmdb/3/search/movie?query=alien');

      expect(upstream.sent.single.url.queryParameters, <String, String>{
        'query': 'alien',
        'api_key': 'tmdb-secret',
      });
    });

    test('should answer 503 when the key the upstream needs is missing',
        () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response = await get(handler, '/proxy/tmdb/3/search/movie');

      expect(response.statusCode, HttpStatus.serviceUnavailable);
      expect(upstream.sent, isEmpty);
    });

    test('should replace the ScreenScraper dev pair and keep client user creds',
        () async {
      final Handler handler = handlerWith(<String, String>{
        CredentialNames.ssDevId: 'dev-id',
        CredentialNames.ssDevPassword: 'dev-pass',
      });

      await get(
        handler,
        '/proxy/screenscraper/api2/jeuRecherche.php'
        '?devid=&devpassword=&ssid=user&sspassword=pw&recherche=mario',
      );

      expect(upstream.sent.single.url.queryParameters, <String, String>{
        'devid': 'dev-id',
        'devpassword': 'dev-pass',
        'ssid': 'user',
        'sspassword': 'pw',
        'recherche': 'mario',
      });
    });

    test('should prefer the server-held ScreenScraper user pair', () async {
      final Handler handler = handlerWith(<String, String>{
        CredentialNames.ssDevId: 'dev-id',
        CredentialNames.ssDevPassword: 'dev-pass',
        CredentialNames.ssSsid: 'server-user',
        CredentialNames.ssSspassword: 'server-pw',
      });

      await get(
        handler,
        '/proxy/screenscraper/api2/ssuserInfos.php?ssid=stale&sspassword=old',
      );

      final Map<String, String> query =
          upstream.sent.single.url.queryParameters;
      expect(query['ssid'], 'server-user');
      expect(query['sspassword'], 'server-pw');
    });

    test('should answer 503 when the ScreenScraper dev pair is missing',
        () async {
      final Handler handler = handlerWith(<String, String>{
        CredentialNames.ssSsid: 'user',
      });

      final Response response =
          await get(handler, '/proxy/screenscraper/api2/jeuRecherche.php');

      expect(response.statusCode, HttpStatus.serviceUnavailable);
      expect(upstream.sent, isEmpty);
    });

    test('should exchange IGDB credentials for a token and cache it', () async {
      final Handler handler = handlerWith(
        <String, String>{
          CredentialNames.igdbClientId: 'cid',
          CredentialNames.igdbClientSecret: 'secret',
        },
        script: <UpstreamResponse>[
          _json(<String, Object?>{'access_token': 'tok', 'expires_in': 5000}),
        ],
        clock: () => DateTime.utc(2026, 1, 1),
      );

      await get(handler, '/proxy/igdb/v4/games');
      await get(handler, '/proxy/igdb/v4/covers');

      // Twitch once, IGDB twice — the second call reused the cached token.
      expect(upstream.sent, hasLength(3));
      expect(upstream.sent.first.url.host, 'id.twitch.tv');
      expect(upstream.sent.first.url.queryParameters['client_secret'], 'secret');
      expect(upstream.sent[1].headers['Client-ID'], 'cid');
      expect(
        upstream.sent[1].headers[HttpHeaders.authorizationHeader],
        'Bearer tok',
      );
      expect(upstream.sent[2].url.host, 'api.igdb.com');
    });

    test('should re-exchange an IGDB token once it has expired', () async {
      DateTime now = DateTime.utc(2026, 1, 1);
      final Handler handler = handlerWith(
        <String, String>{
          CredentialNames.igdbClientId: 'cid',
          CredentialNames.igdbClientSecret: 'secret',
        },
        script: <UpstreamResponse>[
          _json(<String, Object?>{'access_token': 'first', 'expires_in': 120}),
          const UpstreamResponse(status: 200, contentType: null, body: <int>[]),
          _json(<String, Object?>{'access_token': 'second', 'expires_in': 120}),
        ],
        clock: () => now,
      );

      await get(handler, '/proxy/igdb/v4/games');
      now = now.add(const Duration(minutes: 5));
      await get(handler, '/proxy/igdb/v4/games');

      expect(
        upstream.sent.last.headers[HttpHeaders.authorizationHeader],
        'Bearer second',
      );
    });

    test('should report Twitch refusing the credentials as a server problem',
        () async {
      final Handler handler = handlerWith(
        <String, String>{
          CredentialNames.igdbClientId: 'cid',
          CredentialNames.igdbClientSecret: 'wrong',
        },
        script: <UpstreamResponse>[
          _json(<String, Object?>{'message': 'invalid'}, status: 403),
        ],
      );

      final Response response = await get(handler, '/proxy/igdb/v4/games');

      expect(response.statusCode, HttpStatus.serviceUnavailable);
    });

    test('should attach a server-side TheTVDB token to non-login requests',
        () async {
      final Handler handler = handlerWith(
        <String, String>{CredentialNames.tvdb: 'tvdb-key'},
        script: <UpstreamResponse>[
          _json(<String, Object?>{
            'data': <String, Object?>{'token': 'jwt-1'},
          }),
        ],
      );

      await get(handler, '/proxy/tvdb/v4/search?query=fox');
      await get(handler, '/proxy/tvdb/v4/genres');

      // One login (cached token), then the two real calls with the Bearer.
      expect(upstream.sent, hasLength(3));
      expect(upstream.sent.first.url.path, '/v4/login');
      expect(
        upstream.sent[1].headers[HttpHeaders.authorizationHeader],
        'Bearer jwt-1',
      );
      expect(
        upstream.sent[2].headers[HttpHeaders.authorizationHeader],
        'Bearer jwt-1',
      );
    });

    test('should report TheTVDB refusing the key as a server problem',
        () async {
      final Handler handler = handlerWith(
        <String, String>{CredentialNames.tvdb: 'bad-key'},
        script: <UpstreamResponse>[_json(<String, Object?>{}, status: 401)],
      );

      final Response response =
          await get(handler, '/proxy/tvdb/v4/search?query=fox');

      expect(response.statusCode, HttpStatus.serviceUnavailable);
    });

    test('should sign a Douban request server-side and wear its client UA',
        () async {
      final Handler handler = handlerWith(
        <String, String>{
          // The pair this build ships — the only one the probe vector below
          // (and therefore the client signer) is pinned to. Held by reference
          // on purpose: the literal lives in one place, not in every test.
          CredentialNames.doubanKey: kDoubanDefaultKey,
          CredentialNames.doubanSecret: kDoubanDefaultSecret,
        },
        clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      await get(handler, '/proxy/douban/api/v2/book/isbn/9787536692930');

      final Map<String, String> query =
          upstream.sent.single.url.queryParameters;
      expect(upstream.sent.single.url.host, 'frodo.douban.com');
      expect(upstream.sent.single.url.path, '/api/v2/book/isbn/9787536692930');
      expect(query['apiKey'], kDoubanDefaultKey);
      expect(query['_ts'], '1700000000');
      // The vector `probe/douban_sig_vectors.py` prints for this path and
      // timestamp, so the proxy is pinned to the same bytes as the client.
      expect(query['_sig'], 'g9+l253xM80riZQoEdnRsPFqgAs=');
      expect(
        upstream.sent.single.headers[HttpHeaders.userAgentHeader],
        kDoubanUserAgent,
      );
    });

    test('should sign Douban with the shipped pair when none is configured',
        () async {
      // Frodo issues no new keys, so a selfhost install that configures
      // nothing must still search Douban.
      final Handler handler = handlerWith(
        <String, String>{},
        clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      await get(handler, '/proxy/douban/api/v2/book/isbn/9787536692930');

      final Map<String, String> query =
          upstream.sent.single.url.queryParameters;
      expect(upstream.sent.single.url.host, 'frodo.douban.com');
      expect(query['apiKey'], kDoubanDefaultKey);
      // The same vector the configured case produces: the fallback signs the
      // same bytes, so nothing downstream can tell the two apart.
      expect(query['_sig'], 'g9+l253xM80riZQoEdnRsPFqgAs=');
    });

    test('should prefer a configured Douban pair over the shipped one',
        () async {
      final Handler handler = handlerWith(
        <String, String>{
          CredentialNames.doubanKey: 'operator-key',
          CredentialNames.doubanSecret: 'operator-secret',
        },
        clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      await get(handler, '/proxy/douban/api/v2/book/isbn/9787536692930');

      final Map<String, String> query =
          upstream.sent.single.url.queryParameters;
      expect(query['apiKey'], 'operator-key');
      expect(query['_sig'], isNot('g9+l253xM80riZQoEdnRsPFqgAs='));
    });

    test('should replace the key in a TheTVDB login body', () async {
      final Handler handler =
          handlerWith(<String, String>{CredentialNames.tvdb: 'real-tvdb'});

      await handler(Request(
        'POST',
        Uri.parse('http://localhost/proxy/tvdb/v4/login'),
        body: jsonEncode(<String, String>{'apikey': 'server-managed'}),
      ));

      expect(
        jsonDecode(upstream.sent.single.body),
        <String, Object?>{'apikey': 'real-tvdb'},
      );
    });

    test('should treat the Google Books key as optional', () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response =
          await get(handler, '/proxy/googlebooks/books/v1/volumes?q=dune');

      expect(response.statusCode, 200);
      expect(
        upstream.sent.single.url.queryParameters.containsKey('key'),
        isFalse,
      );
    });
  });

  group('POST /proxy/keys', () {
    Future<Response> upload(Handler handler, Map<String, String> body) async =>
        handler(Request(
          'POST',
          Uri.parse('http://localhost/proxy/keys'),
          body: jsonEncode(body),
        ));

    test('should make an uploaded key usable without a restart', () async {
      final Handler handler = handlerWith(<String, String>{});

      await upload(handler, <String, String>{CredentialNames.tmdb: 'fresh'});
      await get(handler, '/proxy/tmdb/3/search/movie');

      expect(upstream.sent.single.url.queryParameters['api_key'], 'fresh');
    });

    test('should ignore a name that is not a credential', () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response =
          await upload(handler, <String, String>{'bogus': 'x'});

      final Object? body = jsonDecode(await response.readAsString());
      expect((body! as Map<String, Object?>).containsKey('bogus'), isFalse);
    });

    test('should keep credentials it was not given', () async {
      final Handler handler =
          handlerWith(<String, String>{CredentialNames.hardcover: 'kept'});

      await upload(handler, <String, String>{CredentialNames.tmdb: 'new'});
      final Response response = await get(handler, '/proxy/keys');

      final Map<String, Object?> body =
          jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect(body[CredentialNames.hardcover], 'kept');
      expect(body[CredentialNames.tmdb], 'new');
    });

    test('should reject a body that is not an object', () async {
      final Handler handler = handlerWith(<String, String>{});

      final Response response = await handler(Request(
        'POST',
        Uri.parse('http://localhost/proxy/keys'),
        body: '"nope"',
      ));

      expect(response.statusCode, HttpStatus.badRequest);
    });
  });

  group('GET /proxy/keys', () {
    test('should return what is set and omit what is not', () async {
      final Handler handler =
          handlerWith(<String, String>{CredentialNames.tmdb: 'tmdb-key'});

      final Response response = await get(handler, '/proxy/keys');
      final Object? body = jsonDecode(await response.readAsString());

      expect(body, containsPair(CredentialNames.tmdb, 'tmdb-key'));
      expect(
        (body! as Map<String, Object?>).containsKey(CredentialNames.hardcover),
        isFalse,
      );
    });
  });
}
