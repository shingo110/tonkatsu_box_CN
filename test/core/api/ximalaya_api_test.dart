import 'dart:convert';

import 'package:core/api/ximalaya_constants.dart';
import 'package:core/models/audio_item.dart';
import 'package:core/models/audio_kind.dart';
import 'package:core/models/data_source.dart';
import 'package:core/utils/ximalaya_json.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/ximalaya/ximalaya_http_client.dart';
import 'package:tonkatsu_box/core/api/ximalaya_api.dart';

import '../../helpers/test_helpers.dart';

DioException _statusError(int status) {
  final RequestOptions options = RequestOptions(path: 'seo');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

Response<dynamic> _okResponse(Object? data) => Response<dynamic>(
      requestOptions: RequestOptions(path: 'seo'),
      statusCode: 200,
      data: data,
    );

Map<String, dynamic> _albumJson({int albumId = 56974128}) =>
    <String, dynamic>{
      'albumId': albumId,
      'title': '《三体》三体解说/三体精简版（5集全）',
      'intro': '三体一共3部，在这里被压缩成为5小集！',
      'nickname': 'Chw丶冬瓜',
      'coverPath': 'storages/ce69-audiofreehighqps/3E/0E/GKwRIJIF2uUuAAI1-gEVyXE1.jpeg',
      'tracksCount': 5,
      'playCount': 1499968,
      // Milliseconds on this API, unlike released_time elsewhere.
      'createdAt': 1789992951650,
    };

Map<String, dynamic> _searchJson(List<dynamic> docs) => <String, dynamic>{
      'ret': 200,
      'data': <String, dynamic>{
        'album': <String, dynamic>{'docs': docs},
      },
    };

void main() {
  group('Ximalaya field readers', () {
    test('reads the album id, and 0 when it is absent', () {
      expect(ximalayaAlbumId(_albumJson()), 56974128);
      expect(ximalayaAlbumId(<String, dynamic>{}), 0);
    });

    test('blank strings read as absent rather than empty', () {
      expect(ximalayaTitle(<String, dynamic>{'title': '  '}), isNull);
      expect(ximalayaIntro(<String, dynamic>{'intro': ''}), isNull);
      expect(ximalayaAnchor(<String, dynamic>{'nickname': ' '}), isNull);
    });

    test('cover path becomes an imagev2.xmcdn.com URL', () {
      expect(
        ximalayaCoverUrl(_albumJson()),
        startsWith('https://imagev2.xmcdn.com/storages/'),
      );
      expect(ximalayaCoverUrl(<String, dynamic>{}), isNull);
      // An absolute URL is left alone.
      expect(
        ximalayaCoverUrl(<String, dynamic>{'coverPath': 'https://x/a.jpg'}),
        'https://x/a.jpg',
      );
    });

    test('episode count treats 0 as unfilled, play count does not', () {
      expect(ximalayaEpisodeCount(_albumJson()), 5);
      expect(
        ximalayaEpisodeCount(<String, dynamic>{'tracksCount': 0}),
        isNull,
      );
      // Nobody has played it yet is an answer, not a gap.
      expect(ximalayaPlayCount(<String, dynamic>{'playCount': 0}), 0);
      expect(ximalayaPlayCount(<String, dynamic>{}), isNull);
    });

    test('createdAt is Unix milliseconds', () {
      expect(ximalayaCreatedAt(_albumJson())?.year, 2026);
      expect(
        ximalayaCreatedAt(<String, dynamic>{'createdAt': 1789992951}),
        isNotNull,
      );
      expect(ximalayaCreatedAt(<String, dynamic>{'createdAt': 0}), isNull);
    });

    test('the album URL is built from the bare id', () {
      expect(
        ximalayaAlbumUrl(56974128),
        'https://www.ximalaya.com/album/56974128',
      );
    });
  });

  group('XimalayaHttpClient', () {
    test('maps the status codes', () {
      final MockDio dio = MockDio();
      when(() => dio.interceptors).thenReturn(Interceptors());
      final XimalayaHttpClient client = XimalayaHttpClient(dio: dio);

      expect(client.handleDioException(_statusError(400), 'f').message,
          'Ximalaya rejected the request');
      expect(client.handleDioException(_statusError(404), 'f').message,
          'Not found');
      expect(client.handleDioException(_statusError(429), 'f').message,
          contains('rate limit'));
    });
  });

  group('XimalayaApi', () {
    late MockDio dio;
    late XimalayaApi api;

    setUp(() {
      dio = MockDio();
      when(() => dio.interceptors).thenReturn(Interceptors());
      api = XimalayaApi(dio: dio);
    });

    test('parses rows into podcast-kind items on the shifted id', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse(
              _searchJson(<dynamic>[_albumJson()])));

      final (List<AudioItem> albums, bool hasMore, int totalPages) =
          await api.searchPodcasts(query: '三体', page: 1);

      expect(albums, hasLength(1));
      final AudioItem album = albums.first;
      expect(album.id, kXimalayaIdOffset + 56974128);
      expect(album.source, DataSource.ximalaya);
      expect(album.kind, AudioKind.podcast);
      expect(album.nativeId, '56974128');
      expect(album.title, contains('三体'));
      expect(album.artists, <String>['Chw丶冬瓜']);
      expect(album.coverUrl, startsWith('https://imagev2.xmcdn.com/'));
      expect(album.trackCount, 5);
      expect(album.listenCount, 1499968);
      expect(album.releaseYear, 2026);
      expect(album.firstReleaseDate, startsWith('2026-'));
      expect(album.externalUrl, 'https://www.ximalaya.com/album/56974128');
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    // The regression this source shipped with once: the body is JSON but the
    // header says `text/plain`, so Dio hands back a String. The transport reads
    // it as text, and the parse has to decode it rather than bail on the type.
    test('parses a String body — the transport reads text/plain', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async =>
              _okResponse(jsonEncode(_searchJson(<dynamic>[_albumJson()]))));

      final (List<AudioItem> albums, _, _) =
          await api.searchPodcasts(query: '三体', page: 1);

      expect(albums, hasLength(1));
      expect(albums.first.title, contains('三体'));
    });

    test('a malformed String body is an empty page, not a crash', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse('<html>blocked</html>'));

      final (List<AudioItem> albums, _, _) =
          await api.searchPodcasts(query: '三体', page: 1);
      expect(albums, isEmpty);
    });

    test('sends the album core and a page number', () async {
      Map<String, dynamic>? captured;
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((Invocation invocation) async {
        captured = invocation.namedArguments[#queryParameters]
            as Map<String, dynamic>?;
        return _okResponse(_searchJson(<dynamic>[]));
      });

      await api.searchPodcasts(query: '三体', page: 3);

      expect(captured?['kw'], '三体');
      expect(captured?['core'], 'album');
      expect(captured?['page'], 3);
      expect(captured?['rows'], kXimalayaPageSize);
    });

    test('a non-200 ret surfaces its own reason', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse(<String, dynamic>{
                'ret': 404,
                'msg': 'no such search word',
              }));

      expect(
        () => api.searchPodcasts(query: ' ', page: 1),
        throwsA(
          isA<XimalayaApiException>()
              .having((XimalayaApiException e) => e.message, 'message',
                  'no such search word'),
        ),
      );
    });

    test('a row that cannot be read is dropped, not the whole page',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse(_searchJson(<dynamic>[
                _albumJson(),
                // `title` as a number fails the cast the readers do.
                <String, dynamic>{'albumId': 1, 'title': 42},
              ])));

      final (List<AudioItem> albums, _, _) =
          await api.searchPodcasts(query: '三体', page: 1);
      expect(albums, hasLength(1));
    });

    test('wraps transport failures in XimalayaApiException', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(_statusError(429));

      expect(() => api.searchPodcasts(query: '三体', page: 1),
          throwsA(isA<XimalayaApiException>()));
    });

    group('findByNativeId', () {
      // No by-id door is open, so the refresh path re-searches the title and
      // matches on album id.
      test('finds the album the stored id points at', () async {
        when(() => dio.get<dynamic>(any(),
                queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => _okResponse(
                _searchJson(<dynamic>[_albumJson(), _albumJson(albumId: 1)])));

        final AudioItem? album = await api.findByNativeId(
          title: '《三体》三体解说/三体精简版（5集全）',
          nativeId: '56974128',
        );

        expect(album, isNotNull);
        expect(album!.id, kXimalayaIdOffset + 56974128);
        expect(album.nativeId, '56974128');
      });

      test('null when the title no longer surfaces the album', () async {
        when(() => dio.get<dynamic>(any(),
                queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async =>
                _okResponse(_searchJson(<dynamic>[_albumJson(albumId: 1)])));

        expect(
          await api.findByNativeId(title: '某节目', nativeId: '56974128'),
          isNull,
        );
      });

      test('a blank title short-circuits without a request', () async {
        expect(
          await api.findByNativeId(title: '   ', nativeId: '1'),
          isNull,
        );
        verifyNever(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')));
      });
    });
  });
}
