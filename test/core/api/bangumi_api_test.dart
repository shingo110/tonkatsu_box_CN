import 'package:core/models/anime.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/manga.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/bangumi_api.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late BangumiApi api;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    api = BangumiApi(dio: mockDio);
  });

  Response<dynamic> makeResponse(dynamic data) => Response<dynamic>(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  Map<String, dynamic> subjectRow(int id) => <String, dynamic>{
        'id': id,
        'name': 'original $id',
        'name_cn': '中文 $id',
        'date': '2020-01-01',
        'platform': 'TV',
        'eps': 12,
        'rating': <String, dynamic>{'score': 7.5},
        'images': <String, dynamic>{'large': 'cover.jpg'},
      };

  Map<String, dynamic> page(List<dynamic> rows, {int total = 2}) =>
      <String, dynamic>{'data': rows, 'total': total};

  DioException dioError({
    int? statusCode,
    DioExceptionType? type,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: ''),
      type: type ?? DioExceptionType.badResponse,
      response: statusCode == null
          ? null
          : Response<dynamic>(
              statusCode: statusCode,
              requestOptions: RequestOptions(path: ''),
            ),
    );
  }

  void stubPost(dynamic data) {
    when(() => mockDio.post<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        )).thenAnswer((_) async => makeResponse(data));
  }

  /// Captures [path, queryParameters, data] from the first search call.
  List<dynamic> captureSearch() {
    return verify(() => mockDio.post<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
          data: captureAny(named: 'data'),
        )).captured;
  }

  group('browseAnime', () {
    test('parses the page and derives hasMore and totalPages', () async {
      stubPost(page(<dynamic>[subjectRow(1), subjectRow(2)], total: 40));

      final (List<Anime> items, bool hasMore, int totalPages) =
          await api.browseAnime(query: '巨人');

      expect(items, hasLength(2));
      expect(items.first.title, '中文 1');
      expect(items.first.source, DataSource.bangumi);
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('hasMore is false on the last page', () async {
      stubPost(page(<dynamic>[subjectRow(1)], total: 21));

      final (List<Anime> items, bool hasMore, int totalPages) =
          await api.browseAnime(page: 2);

      expect(items, hasLength(1));
      expect(hasMore, isFalse);
      expect(totalPages, 2);
    });

    test('derives the offset from the page number', () async {
      stubPost(page(<dynamic>[]));

      await api.browseAnime(page: 3, perPage: 25);

      final List<dynamic> captured = captureSearch();
      expect(captured[0], 'v0/search/subjects');
      expect(
        captured[1],
        <String, dynamic>{'limit': 25, 'offset': 50},
      );
    });

    test('pins the anime subject type and stays sfw', () async {
      stubPost(page(<dynamic>[]));

      await api.browseAnime();

      final Map<String, dynamic> data =
          captureSearch()[2] as Map<String, dynamic>;
      expect(data['keyword'], '');
      expect(data['sort'], 'match');
      final Map<String, dynamic> filter =
          data['filter'] as Map<String, dynamic>;
      expect(filter['type'], <int>[2]);
      expect(filter['nsfw'], isFalse);
    });

    test('omits every filter that was not asked for', () async {
      stubPost(page(<dynamic>[]));

      await api.browseAnime(query: '猫');

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      expect(filter.containsKey('tag'), isFalse);
      expect(filter.containsKey('meta_tags'), isFalse);
      expect(filter.containsKey('air_date'), isFalse);
      expect(filter.containsKey('rating'), isFalse);
      expect(filter.containsKey('rank'), isFalse);
    });

    test('forwards every filter it was given', () async {
      stubPost(page(<dynamic>[]));

      await api.browseAnime(
        metaTags: <String>['TV', '日本'],
        airDate: <String>['>=2020-01-01', '<2021-01-01'],
        rating: <String>['>=8'],
        rank: <String>['>=1', '<=500'],
        sort: 'rank',
      );

      final Map<String, dynamic> data =
          captureSearch()[2] as Map<String, dynamic>;
      expect(data['sort'], 'rank');
      expect(data['filter'], <String, dynamic>{
        'type': <int>[2],
        'meta_tags': <String>['TV', '日本'],
        'air_date': <String>['>=2020-01-01', '<2021-01-01'],
        'rating': <String>['>=8'],
        'rank': <String>['>=1', '<=500'],
        'nsfw': false,
      });
    });

    test('drops an empty filter list instead of sending it', () async {
      stubPost(page(<dynamic>[]));

      await api.browseAnime(tags: <String>[], metaTags: <String>[]);

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      expect(filter.containsKey('tag'), isFalse);
      expect(filter.containsKey('meta_tags'), isFalse);
    });

    test('skips a malformed row without failing the page', () async {
      stubPost(page(<dynamic>[
        subjectRow(1),
        <String, dynamic>{'name': 'no id here'},
        'not an object',
      ]));

      final (List<Anime> items, _, _) = await api.browseAnime();

      expect(items, hasLength(1));
      expect(items.single.id, 1);
    });

    test('reads a non-list data field as an empty page', () async {
      stubPost(<String, dynamic>{'data': null, 'total': 0});

      final (List<Anime> items, bool hasMore, int totalPages) =
          await api.browseAnime();

      expect(items, isEmpty);
      expect(hasMore, isFalse);
      expect(totalPages, 1);
    });

    test('maps a 400 to a filter rejection', () async {
      when(() => mockDio.post<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          )).thenThrow(dioError(statusCode: 400));

      await expectLater(
        api.browseAnime(),
        throwsA(
          isA<BangumiApiException>()
              .having((BangumiApiException e) => e.message, 'message',
                  'Bangumi rejected the search filters')
              .having((BangumiApiException e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('carries a redacted debug detail on failure', () async {
      when(() => mockDio.post<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          )).thenThrow(dioError(statusCode: 403));

      await expectLater(
        api.browseAnime(),
        throwsA(
          isA<BangumiApiException>().having(
            (BangumiApiException e) => e.detail,
            'detail',
            allOf(contains('API: Bangumi'), contains('Status: 403')),
          ),
        ),
      );
    });
  });

  Map<String, dynamic> mangaRow(int id) => <String, dynamic>{
        'id': id,
        'name': 'original $id',
        'name_cn': '中文 $id',
        'date': '2020-01-01',
        'platform': '漫画',
        'eps': 12,
        'volumes': 3,
        'meta_tags': <dynamic>['漫画', '连载中'],
        'rating': <String, dynamic>{'score': 7.5},
        'images': <String, dynamic>{'large': 'cover.jpg'},
      };

  group('browseManga', () {
    test('pins the book subject type and stays sfw', () async {
      stubPost(page(<dynamic>[]));

      await api.browseManga();

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      expect(filter['type'], <int>[1]);
      expect(filter['nsfw'], isFalse);
    });

    test('always sends the manga meta tag, even with no filter picked',
        () async {
      stubPost(page(<dynamic>[]));

      await api.browseManga();

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      // Without it a `type: [1]` search answers novels and picture books.
      expect(filter['meta_tags'], <String>['漫画']);
    });

    test('appends the caller meta tags behind the manga tag', () async {
      stubPost(page(<dynamic>[]));

      await api.browseManga(metaTags: <String>['日本', '连载中']);

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      // Bangumi ANDs the list, so order does not change the result set; the
      // pin is first because it is not the caller's to drop.
      expect(filter['meta_tags'], <String>['漫画', '日本', '连载中']);
    });

    test('forwards the rank bound', () async {
      stubPost(page(<dynamic>[]));

      await api.browseManga(rank: <String>['>=1', '<=500']);

      final Map<String, dynamic> filter =
          (captureSearch()[2] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      expect(filter['rank'], <String>['>=1', '<=500']);
    });

    test('parses rows into Manga of the bangumi source', () async {
      stubPost(page(<dynamic>[mangaRow(3510), mangaRow(3511)], total: 40));

      final (List<Manga> items, bool hasMore, int totalPages) =
          await api.browseManga(query: '海贼王');

      expect(items, hasLength(2));
      expect(items.first.title, '中文 3510');
      expect(items.first.source, DataSource.bangumi);
      expect(items.first.format, 'MANGA');
      expect(items.first.status, 'RELEASING');
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('drops a malformed row without failing the page', () async {
      stubPost(page(<dynamic>[
        <String, dynamic>{'name': 'no id'},
        mangaRow(3510),
      ]));

      final (List<Manga> items, bool _, int _) = await api.browseManga();

      expect(items, hasLength(1));
      expect(items.single.id, 3510);
    });

    test('derives the offset from the page number', () async {
      stubPost(page(<dynamic>[]));

      await api.browseManga(page: 3, perPage: 25);

      expect(
        captureSearch()[1],
        <String, dynamic>{'limit': 25, 'offset': 50},
      );
    });
  });

  group('getAnimeById', () {
    void stubGet(dynamic data) {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => makeResponse(data));
    }

    test('parses a subject payload', () async {
      stubGet(subjectRow(7));

      final Anime? anime = await api.getAnimeById(7);

      expect(anime, isNotNull);
      expect(anime!.id, 7);
      expect(anime.title, '中文 7');
      final List<dynamic> captured = verify(() => mockDio.get<dynamic>(
            captureAny(),
            queryParameters: any(named: 'queryParameters'),
          )).captured;
      expect(captured.single, 'v0/subjects/7');
    });

    test('returns null on a 404', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 404));

      expect(await api.getAnimeById(999999999), isNull);
    });

    test('returns null when the body is not an object', () async {
      stubGet(<dynamic>[]);

      expect(await api.getAnimeById(1), isNull);
    });

    test('rethrows a non-404 failure as a BangumiApiException', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
        dioError(type: DioExceptionType.connectionTimeout),
      );

      await expectLater(
        api.getAnimeById(1),
        throwsA(
          isA<BangumiApiException>().having(
            (BangumiApiException e) => e.message,
            'message',
            'Connection timeout',
          ),
        ),
      );
    });
  });

  group('error mapping', () {
    Future<String> messageFor(DioExceptionType? type, int? status) async {
      when(() => mockDio.post<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          )).thenThrow(dioError(statusCode: status, type: type));

      try {
        await api.browseAnime();
      } on BangumiApiException catch (e) {
        return e.message;
      }
      return 'no exception';
    }

    test('429 reads as a rate limit', () async {
      expect(await messageFor(null, 429),
          'Rate limit exceeded. Please try again later');
    });

    test('offline reads as a connection error', () async {
      expect(await messageFor(DioExceptionType.connectionError, null),
          'No internet connection');
    });

    test('an unmapped status keeps the caller default', () async {
      expect(await messageFor(DioExceptionType.badResponse, 500),
          'Failed to search Bangumi');
    });

    test('toString names the exception', () {
      expect(
        const BangumiApiException('boom', statusCode: 500).toString(),
        'BangumiApiException: boom (status: 500)',
      );
    });
  });
}
