import 'dart:convert';
import 'dart:io';

import 'package:core/api/douban_constants.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tonkatsu_server/src/api_credentials.dart';
import 'package:tonkatsu_server/src/app_handler.dart';
import 'package:tonkatsu_server/src/proxy_handler.dart';
import 'package:tonkatsu_server/src/upstream_client.dart';

/// What the fake upstream saw when the proxy reached it over a real socket.
class _SeenRequest {
  const _SeenRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, List<String>> query;
  final Map<String, String> headers;
  final String body;
}

/// A real HTTP server standing in for the upstream API, so the proxy's outbound
/// leg crosses a socket instead of a function call — the half that the
/// in-process handler tests never exercise.
class _FakeUpstream {
  _FakeUpstream._(this._server);

  static Future<_FakeUpstream> start() async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final _FakeUpstream fake = _FakeUpstream._(server);
    server.listen(fake._handle);
    return fake;
  }

  final HttpServer _server;
  final List<_SeenRequest> seen = <_SeenRequest>[];

  String payload = '{"ok":true}';

  String get origin => 'http://${_server.address.address}:${_server.port}';

  Future<void> _handle(HttpRequest request) async {
    final List<int> body = <int>[
      await for (final List<int> chunk in request) ...chunk,
    ];
    final Map<String, String> headers = <String, String>{};
    request.headers.forEach((String name, List<String> values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    seen.add(_SeenRequest(
      method: request.method,
      path: request.uri.path,
      query: request.uri.queryParametersAll,
      headers: headers,
      body: utf8.decode(body),
    ));

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse('application/json')
      ..add(utf8.encode(payload));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// Redirects the proxy's outbound call onto the fake upstream while keeping
/// method, path, query, headers and body exactly as the proxy built them.
class _ReroutedUpstream implements UpstreamClient {
  _ReroutedUpstream(this.origin);

  final String origin;

  @override
  Future<UpstreamResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<int>? body,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final Uri rerouted = Uri.parse(origin).replace(
        path: url.path,
        query: url.query.isEmpty ? null : url.query,
      );
      final HttpClientRequest request = await client.openUrl(method, rerouted);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        if (body.isNotEmpty) request.add(body);
      }
      final HttpClientResponse response = await request.close();
      final List<int> bytes = <int>[
        await for (final List<int> chunk in response) ...chunk,
      ];
      return UpstreamResponse(
        status: response.statusCode,
        contentType: response.headers.contentType?.toString(),
        body: bytes,
      );
    } finally {
      client.close();
    }
  }
}

/// A reply as the caller received it, bytes intact.
class _Reply {
  const _Reply(this.status, this.body, this.contentType);

  final int status;
  final String body;
  final String? contentType;
}

void main() {
  late _FakeUpstream upstream;

  setUp(() async {
    upstream = await _FakeUpstream.start();
  });

  tearDown(() => upstream.close());

  Future<HttpServer> serve({
    Map<String, String> keys = const <String, String>{},
    String? webRoot,
  }) async {
    final HttpServer server = await shelf_io.serve(
      buildAppHandler(
        schemaVersion: 3,
        proxy: ApiProxy(
          credentials: ApiCredentials(keys),
          upstream: _ReroutedUpstream(upstream.origin),
          // Fixed so the Douban signature is a reproducible vector.
          clock: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
        webRoot: webRoot,
        logger: (Handler inner) => inner,
      ),
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    return server;
  }

  /// Sends what a browser would: no User-Agent, and only the headers a page is
  /// allowed to choose.
  Future<_Reply> send(
    HttpServer server,
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.openUrl(
        method,
        Uri.parse('http://${server.address.address}:${server.port}$path'),
      );
      headers?.forEach(request.headers.set);
      if (body != null) {
        final List<int> bytes = utf8.encode(body);
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final HttpClientResponse response = await request.close();
      return _Reply(
        response.statusCode,
        await response.transform(utf8.decoder).join(),
        response.headers.contentType?.toString(),
      );
    } finally {
      client.close();
    }
  }

  group('self-hosted /proxy over real sockets', () {
    test('should carry a keyless call out and back with the server UA',
        () async {
      final HttpServer server = await serve();

      final _Reply reply = await send(
        server,
        'GET',
        '/proxy/bangumi/v0/subjects/3510?air_date=%3E%3D2014-01-01',
      );

      expect(reply.status, HttpStatus.ok);
      expect(jsonDecode(reply.body), <String, Object?>{'ok': true});
      expect(reply.contentType, contains('application/json'));

      final _SeenRequest sent = upstream.seen.single;
      expect(sent.method, 'GET');
      expect(sent.path, '/v0/subjects/3510');
      expect(sent.query['air_date'], <String>['>=2014-01-01']);
      // A browser strips User-Agent; the proxy is why Bangumi's Cloudflare
      // does not answer 403 to the web build.
      expect(sent.headers[HttpHeaders.userAgentHeader], kProxyUserAgent);
    });

    test('should refuse an upstream that is not on the allowlist', () async {
      final HttpServer server = await serve();

      final _Reply reply =
          await send(server, 'GET', '/proxy/evil.example/steal');

      expect(reply.status, HttpStatus.notFound);
      expect(upstream.seen, isEmpty);
    });

    test('should answer 503 when the key the upstream needs is missing',
        () async {
      final HttpServer server = await serve();

      final _Reply reply =
          await send(server, 'GET', '/proxy/tmdb/3/search/movie');

      expect(reply.status, HttpStatus.serviceUnavailable);
      expect(upstream.seen, isEmpty);
    });

    test('should pass a POST body through intact', () async {
      final HttpServer server = await serve();
      const String body = '{"keyword":"海贼王","sort":"rank"}';

      final _Reply reply = await send(
        server,
        'POST',
        '/proxy/bangumi/v0/search/subjects',
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: body,
      );

      expect(reply.status, HttpStatus.ok);
      final _SeenRequest sent = upstream.seen.single;
      expect(sent.method, 'POST');
      expect(sent.body, body);
      expect(
        sent.headers[HttpHeaders.contentTypeHeader],
        contains('application/json'),
      );
    });

    test('should keep every value of a repeated query parameter', () async {
      final HttpServer server = await serve();

      await send(server, 'GET', '/proxy/tvmaze/search?q=a&q=b');

      expect(upstream.seen.single.query['q'], <String>['a', 'b']);
    });

    test('should not let a caller smuggle its own Authorization', () async {
      final HttpServer server = await serve();

      await send(
        server,
        'GET',
        '/proxy/anilist/graphql',
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer stolen',
        },
      );

      expect(
        upstream.seen.single.headers[HttpHeaders.authorizationHeader],
        isNull,
      );
    });

    test('should sign a Douban call server-side before it leaves', () async {
      final HttpServer server = await serve(keys: <String, String>{
        CredentialNames.doubanKey: '0dad551ec0f84ed02907ff5c42e8ec70',
        CredentialNames.doubanSecret: 'bf7dddc7c9cfe6f7',
      });

      final _Reply reply = await send(
        server,
        'GET',
        '/proxy/douban/api/v2/book/isbn/9787536692930',
      );

      expect(reply.status, HttpStatus.ok);
      final _SeenRequest sent = upstream.seen.single;
      expect(sent.path, '/api/v2/book/isbn/9787536692930');
      expect(
        sent.query['apiKey'],
        <String>['0dad551ec0f84ed02907ff5c42e8ec70'],
      );
      expect(sent.query['_ts'], <String>['1700000000']);
      // The vector `probe/douban_sig_vectors.py` prints for this path and
      // timestamp, so the signed request is pinned to the same bytes as the
      // client-side signer.
      expect(sent.query['_sig'], <String>['g9+l253xM80riZQoEdnRsPFqgAs=']);
      expect(sent.headers[HttpHeaders.userAgentHeader], kDoubanUserAgent);
    });

    test('should take a key upload over the socket and use it at once',
        () async {
      final HttpServer server = await serve();

      await send(
        server,
        'POST',
        '/proxy/keys',
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode(<String, String>{CredentialNames.tmdb: 'fresh'}),
      );
      await send(server, 'GET', '/proxy/tmdb/3/search/movie');

      expect(upstream.seen.single.query['api_key'], <String>['fresh']);
    });

    test('should answer 404 rather than the app shell for a bad upstream',
        () async {
      final Directory web =
          Directory.systemTemp.createTempSync('tonkatsu_web_root');
      addTearDown(() => web.deleteSync(recursive: true));
      File(p.join(web.path, 'index.html')).writeAsStringSync('<html>shell</html>');
      final HttpServer server = await serve(webRoot: web.path);

      final _Reply missing =
          await send(server, 'GET', '/proxy/evil.example/steal');
      final _Reply route = await send(server, 'GET', '/library');

      // Without the API/static split a `Cascade` would hand back index.html
      // with a 200 here, which reads as success and buries the mistake.
      expect(missing.status, HttpStatus.notFound);
      expect(missing.body, isNot(contains('shell')));
      // A client-side route still falls back to the shell.
      expect(route.status, HttpStatus.ok);
      expect(route.body, contains('shell'));
    });
  });
}
