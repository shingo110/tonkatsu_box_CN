import 'package:core/models/movie.dart';
import 'package:core/models/tv_show.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late DoubanApi api;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    // The client attaches its signing interceptor to whatever Dio it gets.
    when(() => mockDio.interceptors).thenReturn(Interceptors());
    api = DoubanApi(dio: mockDio)..setCredentials('key', 'secret');
  });

  Response<dynamic> makeResponse(dynamic data) => Response<dynamic>(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  void stubGet(dynamic data) {
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => makeResponse(data));
  }

  List<dynamic> captureGet() => verify(() => mockDio.get<dynamic>(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
      )).captured;

  /// One `/api/v2/search/movie` row. The endpoint answers films and series out
  /// of the same pool, so `target_type` is the only thing separating them.
  Map<String, dynamic> subjectRow(
    String id, {
    required String kind,
    required String title,
  }) =>
      <String, dynamic>{
        'layout': 'subject',
        'target': <String, dynamic>{
          'id': id,
          'title': title,
          'year': '2023',
          'card_subtitle': '中国大陆 / 科幻 冒险 灾难 / 郭帆 / 吴京 刘德华',
          'uri': 'douban://douban.com/$kind/$id',
          'rating': <String, dynamic>{'count': 100, 'max': 10, 'value': 8.3},
        },
        'target_id': id,
        'target_type': kind,
        'type_name': kind == 'movie' ? '电影' : '电视剧',
      };

  Map<String, dynamic> searchPage(List<dynamic> items, {int total = 27}) =>
      <String, dynamic>{
        'total': total,
        'start': 0,
        'count': 20,
        'banned': '',
        'items': items,
      };

  group('searchMovies', () {
    test('keeps only the film rows of a mixed page', () async {
      stubGet(searchPage(<dynamic>[
        subjectRow('26647087', kind: 'tv', title: '三体'),
        subjectRow('21335171', kind: 'movie', title: '三体'),
        subjectRow('34444648', kind: 'tv', title: '三体'),
      ]));

      final (List<Movie> movies, bool hasMore, int totalPages) =
          await api.searchMovies(query: '三体');

      expect(movies, hasLength(1));
      expect(movies.single.tmdbId, 21335171);
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('pages over the mixed pool, not over the surviving rows', () async {
      // Twenty rows, one of them a film. `total` counts both kinds, so a page
      // whose films were filtered out still has to advance the offset.
      stubGet(
        searchPage(
          <dynamic>[
            for (int i = 0; i < 19; i++)
              subjectRow('$i', kind: 'tv', title: '剧 $i'),
            subjectRow('21335171', kind: 'movie', title: '三体'),
          ],
        ),
      );

      final (List<Movie> movies, bool hasMore, int _) =
          await api.searchMovies(query: '三体');

      expect(movies, hasLength(1));
      // 0 + 20 rows seen < 27 total, even though one film came through.
      expect(hasMore, isTrue);
    });

    test('sends an offset, not a page number', () async {
      stubGet(searchPage(<dynamic>[]));

      await api.searchMovies(query: '流浪地球', page: 3);

      final List<dynamic> captured = captureGet();
      final Map<String, dynamic> params =
          captured[1] as Map<String, dynamic>;
      expect(captured[0], '/api/v2/search/movie');
      expect(params['q'], '流浪地球');
      expect(params['start'], 40);
      expect(params['count'], 20);
    });

    test('answers an empty page for a payload without items', () async {
      stubGet(<String, dynamic>{'total': 0});

      final (List<Movie> movies, bool hasMore, int totalPages) =
          await api.searchMovies(query: '三体');

      expect(movies, isEmpty);
      expect(hasMore, isFalse);
      expect(totalPages, 0);
    });
  });

  group('searchTvShows', () {
    test('keeps only the series rows', () async {
      stubGet(searchPage(<dynamic>[
        subjectRow('26647087', kind: 'tv', title: '三体'),
        subjectRow('21335171', kind: 'movie', title: '三体'),
      ]));

      final (List<TvShow> shows, bool _, int _) =
          await api.searchTvShows(query: '三体');

      expect(shows, hasLength(1));
      expect(shows.single.tmdbId, 26647087);
    });

    test('sends the same mixed endpoint as the film search', () async {
      stubGet(searchPage(<dynamic>[]));

      await api.searchTvShows(query: '狂飙');

      expect(captureGet()[0], '/api/v2/search/movie');
    });
  });

  group('getMovie and getTvShow', () {
    test('getMovie hits the film path', () async {
      stubGet(<String, dynamic>{'id': '35267208', 'title': '流浪地球2'});

      final Movie? movie = await api.getMovie('35267208');

      expect(captureGet()[0], '/api/v2/movie/35267208');
      expect(movie?.title, '流浪地球2');
    });

    test('getTvShow hits the series path', () async {
      stubGet(<String, dynamic>{'id': '35465232', 'title': '狂飙'});

      final TvShow? show = await api.getTvShow('35465232');

      // A series id sent to /movie/ answers 996, so the path is load-bearing.
      expect(captureGet()[0], '/api/v2/tv/35465232');
      expect(show?.title, '狂飙');
    });

    test('answers null for an error envelope instead of throwing', () async {
      stubGet(<String, dynamic>{'code': 996, 'msg': 'invalid_request'});

      expect(await api.getMovie('1'), isNull);
      expect(await api.getTvShow('1'), isNull);
    });
  });

  group('without credentials', () {
    test('skips the network on a native build', () async {
      final DoubanApi bare = DoubanApi(dio: mockDio);

      final (List<Movie> movies, bool hasMore, int _) =
          await bare.searchMovies(query: '三体');
      final (List<TvShow> shows, bool _, int _) =
          await bare.searchTvShows(query: '三体');
      final Movie? movie = await bare.getMovie('35267208');
      final TvShow? show = await bare.getTvShow('35465232');

      expect(movies, isEmpty);
      expect(shows, isEmpty);
      expect(hasMore, isFalse);
      expect(movie, isNull);
      expect(show, isNull);
      verifyNever(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });
  });
}
