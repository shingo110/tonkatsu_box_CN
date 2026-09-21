import 'package:core/api/taptap_constants.dart';
import 'package:core/models/game.dart';
import 'package:core/utils/taptap_json.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/taptap/taptap_http_client.dart';
import 'package:tonkatsu_box/core/api/taptap_api.dart';

import '../../helpers/test_helpers.dart';

DioException _statusError(int status) {
  final RequestOptions options = RequestOptions(path: 'app-search');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: options, statusCode: status),
  );
}

Response<dynamic> _okResponse(Object? data) => Response<dynamic>(
      requestOptions: RequestOptions(path: 'app-search'),
      statusCode: 200,
      data: data,
    );

/// One search row. Search rows and detail records share these keys, so this
/// stands in for both.
Map<String, dynamic> _appJson({int id = 168332}) => <String, dynamic>{
      'id': id,
      'title': '原神',
      'description': <String, dynamic>{'text': '<p>开放世界<b>冒险</b>游戏</p>'},
      'icon': <String, dynamic>{
        'url': 'https://img-tc.tapimg.com/a.png/_tap_appicon.jpg',
        'medium_url': 'https://img-tc.tapimg.com/a.png/_tap_appicon_m.jpg',
      },
      'cover': <String, dynamic>{'url': 'https://img-tc.tapimg.com/b.jpg'},
      'stat': <String, dynamic>{
        'rating': <String, dynamic>{'score': '7.9'},
        'vote_info': <String, dynamic>{
          '1': 10,
          '2': 20,
          '3': 30,
          '4': 40,
          '5': 50,
        },
      },
      'tags': <dynamic>[
        <String, dynamic>{'value': '角色扮演'},
        <String, dynamic>{'value': '开放世界'},
      ],
      'developers': <dynamic>[
        <String, dynamic>{'name': '米哈游'},
      ],
      'released_time': 1600000000,
    };

void main() {
  group('TapTap field readers', () {
    test('reads the bare app id, and 0 when it is absent', () {
      expect(taptapAppId(_appJson()), 168332);
      expect(taptapAppId(<String, dynamic>{}), 0);
    });

    test('strips HTML off the description and drops a blank one', () {
      expect(taptapDescription(_appJson()), isNot(contains('<')));
      expect(taptapDescription(<String, dynamic>{}), isNull);
      expect(
        taptapDescription(<String, dynamic>{
          'description': <String, dynamic>{'text': '   '},
        }),
        isNull,
      );
    });

    test('prefers the medium icon and falls back to the plain one', () {
      expect(taptapIconUrl(_appJson()), endsWith('_tap_appicon_m.jpg'));
      expect(
        taptapIconUrl(<String, dynamic>{
          'icon': <String, dynamic>{'url': 'https://x/a.jpg'},
        }),
        'https://x/a.jpg',
      );
      expect(taptapIconUrl(<String, dynamic>{}), isNull);
    });

    test('banner art falls back from cover to banner', () {
      expect(taptapArtworkUrl(_appJson()), 'https://img-tc.tapimg.com/b.jpg');
      expect(
        taptapArtworkUrl(<String, dynamic>{
          'banner': <String, dynamic>{'url': 'https://x/ban.jpg'},
        }),
        'https://x/ban.jpg',
      );
    });

    test('score is a string on a 0-10 scale, returned on 0-100', () {
      expect(taptapRating(_appJson()), 79.0);
      // Unreleased apps carry no score, and a broken one is dropped rather
      // than read as zero.
      expect(taptapRating(<String, dynamic>{}), isNull);
      expect(
        taptapRating(<String, dynamic>{
          'stat': <String, dynamic>{
            'rating': <String, dynamic>{'score': '—'},
          },
        }),
        isNull,
      );
    });

    test('vote total sums the five buckets; none at all reads null', () {
      expect(taptapRatingCount(_appJson()), 150);
      expect(taptapRatingCount(<String, dynamic>{}), isNull);
      expect(
        taptapRatingCount(<String, dynamic>{
          'stat': <String, dynamic>{
            'vote_info': <String, dynamic>{'1': 0, '2': 0},
          },
        }),
        isNull,
      );
    });

    test('tags are capped so a heavily tagged app cannot flood a row', () {
      final List<dynamic> many = <dynamic>[
        for (int i = 0; i < 30; i++) <String, dynamic>{'value': 'tag$i'},
      ];
      expect(taptapGenres(<String, dynamic>{'tags': many}), hasLength(12));
      expect(taptapGenres(_appJson()), <String>['角色扮演', '开放世界']);
      expect(taptapGenres(<String, dynamic>{}), isEmpty);
    });

    test('the developer comes from the labelled developers entry', () {
      expect(taptapStudio(_appJson()), '米哈游');
      expect(taptapStudio(<String, dynamic>{}), isNull);
    });

    test('released_time is seconds, 0 meaning unreleased', () {
      expect(taptapReleaseDate(_appJson())?.year, 2020);
      expect(taptapReleaseDate(<String, dynamic>{'released_time': 0}), isNull);
      expect(taptapReleaseDate(<String, dynamic>{}), isNull);
    });
  });

  group('TapTapHttpClient', () {
    test('maps the status codes, the 400 being the missing client header',
        () {
      final MockDio dio = MockDio();
      when(() => dio.interceptors).thenReturn(Interceptors());
      final TapTapHttpClient client = TapTapHttpClient(dio: dio);

      expect(client.handleDioException(_statusError(400), 'f').message,
          contains('client header'));
      expect(client.handleDioException(_statusError(404), 'f').message,
          'Not found');
      expect(client.handleDioException(_statusError(429), 'f').message,
          contains('rate limit'));
      expect(
        client
            .handleDioException(
              DioException(
                requestOptions: RequestOptions(path: 'x'),
                type: DioExceptionType.connectionTimeout,
              ),
              'f',
            )
            .message,
        'Connection timeout',
      );
      expect(
        client
            .handleDioException(
              DioException(
                requestOptions: RequestOptions(path: 'x'),
                type: DioExceptionType.connectionError,
              ),
              'f',
            )
            .message,
        'No internet connection',
      );
    });
  });

  group('TapTapApi', () {
    late MockDio dio;
    late TapTapApi api;

    setUp(() {
      dio = MockDio();
      when(() => dio.interceptors).thenReturn(Interceptors());
      api = TapTapApi(dio: dio);
    });

    test('search parses a row into a game on the shifted id', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse(<String, dynamic>{
                'data': <String, dynamic>{
                  'list': <dynamic>[_appJson()],
                },
              }));

      final (List<Game> games, bool hasMore, int totalPages) =
          await api.searchGames(query: '原神', page: 1);

      expect(games, hasLength(1));
      final Game game = games.first;
      expect(game.id, kTapTapIdOffset + 168332);
      expect(game.isFromTapTap, isTrue);
      expect(game.tapTapAppId, 168332);
      expect(game.name, '原神');
      expect(game.summary, isNot(contains('<')));
      expect(game.coverUrl, endsWith('_tap_appicon_m.jpg'));
      expect(game.artworkUrl, 'https://img-tc.tapimg.com/b.jpg');
      expect(game.rating, 79.0);
      expect(game.ratingCount, 150);
      expect(game.genres, containsAll(<String>['角色扮演', '开放世界']));
      expect(game.externalUrl, 'https://www.taptap.cn/app/168332');
      // TapTap lists one Android/iOS build, so there is no platform table to
      // resolve and the picker must not wait on one.
      expect(game.platformIds, isNull);
      expect(game.releaseDate?.year, 2020);
      expect(game.formattedRating, '7.9');
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('search sends the keyword, the app type and an offset', () async {
      Map<String, dynamic>? captured;
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((Invocation invocation) async {
        captured = invocation.namedArguments[#queryParameters]
            as Map<String, dynamic>?;
        return _okResponse(<String, dynamic>{});
      });

      await api.searchGames(query: '原神', page: 3);

      expect(captured?['kw'], '原神');
      expect(captured?['type'], 'app');
      // Page numbers are spelled as offsets on the wire.
      expect(captured?['from'], kTapTapPageSize * 2);
    });

    test('a row that cannot be read is dropped, not the whole page',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse(<String, dynamic>{
                'data': <String, dynamic>{
                  'list': <dynamic>[
                    _appJson(),
                    // `title` as a number fails the cast the readers do.
                    <String, dynamic>{'id': 1, 'title': 123},
                    'not an object',
                  ],
                },
              }));

      final (List<Game> games, _, _) =
          await api.searchGames(query: '原神', page: 1);

      expect(games, hasLength(1));
      expect(games.first.name, '原神');
    });

    test('an unexpected body shape is an empty page, not a crash', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _okResponse('not a map'));

      final (List<Game> games, _, _) =
          await api.searchGames(query: '原神', page: 1);
      expect(games, isEmpty);
    });

    test('search wraps transport failures in TapTapApiException', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(_statusError(429));

      expect(() => api.searchGames(query: '原神', page: 1),
          throwsA(isA<TapTapApiException>()));
    });

    group('getGameById', () {
      test('takes the shifted model id and returns the record', () async {
        when(() => dio.get<dynamic>(any(),
                queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async =>
                _okResponse(<String, dynamic>{'data': _appJson()}));

        final Game? game = await api.getGameById(kTapTapIdOffset + 168332);

        expect(game, isNotNull);
        expect(game!.id, kTapTapIdOffset + 168332);
        expect(game.name, '原神');
      });

      test('a bare app id is refused rather than sent', () async {
        // 168332 is below the offset, so it is not a TapTap model id at all —
        // sending it would ask IGDB's id space for a TapTap record.
        expect(await api.getGameById(168332), isNull);
        verifyNever(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')));
      });

      test('a record-less body is null', () async {
        when(() => dio.get<dynamic>(any(),
                queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => _okResponse(<String, dynamic>{
                  'data': null,
                }));

        expect(await api.getGameById(kTapTapIdOffset + 1), isNull);
      });

      test('wraps transport failures', () async {
        when(() => dio.get<dynamic>(any(),
                queryParameters: any(named: 'queryParameters')))
            .thenThrow(_statusError(404));

        expect(
          () => api.getGameById(kTapTapIdOffset + 1),
          throwsA(isA<TapTapApiException>()),
        );
      });
    });
  });
}
