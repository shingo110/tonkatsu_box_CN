import 'dart:convert';

import 'package:core/api/psn_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/psn/psn_library_client.dart';
import 'package:tonkatsu_box/core/api/psn/psn_types.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late PsnLibraryClient client;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    client = PsnLibraryClient(dio: mockDio);
  });

  Response<dynamic> makeResponse(Object? data, {int status = 200}) =>
      Response<dynamic>(
        data: data,
        statusCode: status,
        requestOptions: RequestOptions(path: ''),
      );

  Map<String, dynamic> gamesPage(List<String> names) => <String, dynamic>{
        'data': <String, dynamic>{
          'purchasedTitlesRetrieve': <String, dynamic>{
            'games': <Map<String, dynamic>>[
              for (final String name in names)
                <String, dynamic>{
                  'name': name,
                  'titleId': 'PPSA_${name.replaceAll(' ', '_')}',
                  'image': <String, dynamic>{'url': 'https://img/$name.png'},
                  'platform': 'PS5',
                },
            ],
          },
        },
      };

  /// Answers each successive request from [pages]; the last one repeats.
  void stubPages(List<Response<dynamic>> pages) {
    int index = 0;
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async {
      final Response<dynamic> response =
          pages[index < pages.length ? index : pages.length - 1];
      index++;
      return response;
    });
  }

  List<Map<String, dynamic>> capturedQueries() => verify(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured.cast<Map<String, dynamic>>();

  Map<String, dynamic> variablesOf(Map<String, dynamic> query) =>
      jsonDecode(query['variables'] as String) as Map<String, dynamic>;

  group('fetchPurchasedGames', () {
    test('reads a short page and stops', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>['God of War', 'Bloodborne'])),
      ]);

      final List<PsnPurchasedGame> games =
          await client.fetchPurchasedGames(accessToken: 'jwt');

      expect(games.map((PsnPurchasedGame g) => g.name),
          <String>['God of War', 'Bloodborne']);
      expect(games.first.titleId, 'PPSA_God_of_War');
      expect(games.first.imageUrl, 'https://img/God of War.png');
      expect(games.first.platform, 'PS5');
      expect(capturedQueries(), hasLength(1));
    });

    test('sends the persisted query by name, hash and variables', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>['Solo'])),
      ]);

      await client.fetchPurchasedGames(accessToken: 'jwt');

      final Map<String, dynamic> query = capturedQueries().single;
      expect(query['operationName'], kPsnPurchasedGameListOperation);

      final Map<String, dynamic> extensions =
          jsonDecode(query['extensions'] as String) as Map<String, dynamic>;
      final Map<String, dynamic> persisted =
          extensions['persistedQuery'] as Map<String, dynamic>;
      expect(persisted['version'], 1);
      expect(persisted['sha256Hash'], kPsnPurchasedGameListHash);

      final Map<String, dynamic> variables = variablesOf(query);
      expect(variables['isActive'], isTrue);
      expect(variables['platform'], <String>['ps4', 'ps5']);
      expect(variables['size'], kPsnPurchasedPageSize);
      expect(variables['start'], 0);
      expect(variables['sortBy'], 'ACTIVE_DATE');
    });

    test('carries the JWT as a Bearer token off web builds', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>['Solo'])),
      ]);

      await client.fetchPurchasedGames(accessToken: '  jwt  ');

      final Options options = verify(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured.single as Options;
      expect(options.headers?['Authorization'], 'Bearer jwt');
    });

    test('declares a JSON content type on the body-less GET', () async {
      // Sony's Apollo gateway answers a request that carries no Content-Type
      // with "blocked as a potential Cross-Site Request Forgery" — and this GET
      // puts its whole payload in the query string, so Dio sends no body and
      // therefore no Content-Type unless it is declared here. Dropping it
      // breaks the whole feature on device while every other test stays green.
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>['Solo'])),
      ]);

      await client.fetchPurchasedGames(accessToken: 'jwt');

      final Options options = verify(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured.single as Options;
      expect(options.contentType, 'application/json');
    });

    test('walks to the next page while a full one keeps arriving', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>[
          for (int i = 0; i < kPsnPurchasedPageSize; i++) 'Game $i',
        ])),
        makeResponse(gamesPage(<String>['Tail one', 'Tail two'])),
      ]);

      final List<PsnPurchasedGame> games =
          await client.fetchPurchasedGames(accessToken: 'jwt');

      expect(games, hasLength(kPsnPurchasedPageSize + 2));
      final List<Map<String, dynamic>> queries = capturedQueries();
      expect(queries, hasLength(2));
      expect(variablesOf(queries.first)['start'], 0);
      expect(variablesOf(queries.last)['start'], kPsnPurchasedPageSize);
    });

    test('reports progress as pages land', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>['A', 'B'])),
      ]);

      final List<int> seen = <int>[];
      await client.fetchPurchasedGames(
        accessToken: 'jwt',
        onPage: seen.add,
      );

      expect(seen, <int>[2]);
    });

    test('collapses a game owned on both platforms to one row', () async {
      // The store lists one entry per platform version; the library is a list
      // of games, not of entitlements.
      stubPages(<Response<dynamic>>[
        makeResponse(gamesPage(<String>[
          'The Last of Us Part II',
          'The Last of Us Part II',
          'Bloodborne',
        ])),
      ]);

      final List<PsnPurchasedGame> games =
          await client.fetchPurchasedGames(accessToken: 'jwt');

      expect(games.map((PsnPurchasedGame g) => g.name),
          <String>['The Last of Us Part II', 'Bloodborne']);
    });

    test('drops a row the store left without a name', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(<String, dynamic>{
          'data': <String, dynamic>{
            'purchasedTitlesRetrieve': <String, dynamic>{
              'games': <Map<String, dynamic>>[
                <String, dynamic>{'name': '   ', 'titleId': 'X'},
                <String, dynamic>{'name': 'Real Game', 'titleId': 'Y'},
              ],
            },
          },
        }),
      ]);

      final List<PsnPurchasedGame> games =
          await client.fetchPurchasedGames(accessToken: 'jwt');

      expect(games.map((PsnPurchasedGame g) => g.name), <String>['Real Game']);
    });

    test('refuses an empty token without spending a request', () async {
      expect(
        () => client.fetchPurchasedGames(accessToken: ' '),
        throwsA(isA<PsnApiException>()),
      );
      verifyNever(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ));
    });

    test('surfaces a GraphQL errors array returned with HTTP 200', () async {
      stubPages(<Response<dynamic>>[
        makeResponse(<String, dynamic>{
          'errors': <Map<String, dynamic>>[
            <String, dynamic>{'message': 'Not authenticated'},
          ],
        }),
      ]);

      expect(
        () => client.fetchPurchasedGames(accessToken: 'stale'),
        throwsA(
          isA<PsnApiException>().having(
            (PsnApiException e) => e.message,
            'message',
            'Not authenticated',
          ),
        ),
      );
    });

    test('maps an expired session to a sign-in prompt', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
      ));

      expect(
        () => client.fetchPurchasedGames(accessToken: 'jwt'),
        throwsA(
          isA<PsnApiException>().having(
            (PsnApiException e) => e.message,
            'message',
            contains('Sign in again'),
          ),
        ),
      );
    });
  });

  group('fetchPlayedGames', () {
    Map<String, dynamic> playedPage(
      List<String> names, {
      List<String>? localized,
    }) {
      return <String, dynamic>{
        'titles': <Map<String, dynamic>>[
          for (int i = 0; i < names.length; i++)
            <String, dynamic>{
              'titleId': 'CUSA_${names[i].replaceAll(' ', '_')}',
              'name': names[i],
              if (localized != null && i < localized.length)
                'localizedName': localized[i],
              'imageUrl': 'https://img/${names[i]}.png',
              'category': 'ps5_native_game',
            },
        ],
      };
    }

    void stubPlayedPages(List<Response<dynamic>> pages) {
      int index = 0;
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async {
        final Response<dynamic> response =
            pages[index < pages.length ? index : pages.length - 1];
        index++;
        return response;
      });
    }

    List<Map<String, dynamic>> capturedQueries() => verify(
          () => mockDio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).captured.cast<Map<String, dynamic>>();

    test('reads the play history off the mobile host, not the store', () async {
      // The PlayStation Plus half of the library lives on another domain; a
      // call that went to the store's host would silently return purchases.
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(playedPage(<String>['Hogwarts Legacy'])),
      ]);

      await client.fetchPlayedGames(accessToken: 'jwt');

      final String path = verify(() => mockDio.get<dynamic>(
            captureAny(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).captured.single as String;
      expect(path, startsWith('https://m.np.playstation.com'));
      expect(path, contains('/api/gamelist/v2/users/me/titles'));
    });

    test('asks for the console categories and pages by offset', () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(playedPage(<String>[
          for (int i = 0; i < kPsnPlayedGamesPageSize; i++) 'Game $i',
        ])),
        makeResponse(playedPage(<String>['Tail'])),
      ]);

      final List<PsnPlayedGame> games =
          await client.fetchPlayedGames(accessToken: 'jwt');

      expect(games, hasLength(kPsnPlayedGamesPageSize + 1));
      final List<Map<String, dynamic>> queries = capturedQueries();
      expect(queries, hasLength(2));
      expect(queries.first['categories'], kPsnPlayedGamesCategories);
      expect(queries.first['limit'], kPsnPlayedGamesPageSize);
      expect(queries.first['offset'], 0);
      expect(queries.last['offset'], kPsnPlayedGamesPageSize);
    });

    test('stops on a short page', () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(playedPage(<String>['A', 'B'])),
      ]);

      await client.fetchPlayedGames(accessToken: 'jwt');

      expect(capturedQueries(), hasLength(1));
    });

    test('collapses the same title listed twice to one row', () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(playedPage(<String>['Bloodborne', 'bloodborne'])),
      ]);

      final List<PsnPlayedGame> games =
          await client.fetchPlayedGames(accessToken: 'jwt');

      expect(games.map((PsnPlayedGame g) => g.displayName), <String>['Bloodborne']);
    });

    test('drops a row Sony left without a name', () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(<String, dynamic>{
          'titles': <Map<String, dynamic>>[
            <String, dynamic>{'titleId': 'X', 'name': '  '},
            <String, dynamic>{'titleId': 'Y', 'name': 'Real Game'},
          ],
        }),
      ]);

      final List<PsnPlayedGame> games =
          await client.fetchPlayedGames(accessToken: 'jwt');

      expect(games.map((PsnPlayedGame g) => g.displayName), <String>['Real Game']);
    });

    test('falls back to the localized name when the plain one is missing',
        () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(<String, dynamic>{
          'titles': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': '',
              'localizedName': '霍格沃茨之遗',
            },
          ],
        }),
      ]);

      final List<PsnPlayedGame> games =
          await client.fetchPlayedGames(accessToken: 'jwt');

      expect(games.single.displayName, '霍格沃茨之遗');
      expect(games.single.localizedName, '霍格沃茨之遗');
    });

    test('declares a content type here too, and carries the JWT', () async {
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(playedPage(<String>['Solo'])),
      ]);

      await client.fetchPlayedGames(accessToken: '  jwt  ');

      final Options options = verify(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured.single as Options;
      expect(options.contentType, 'application/json');
      expect(options.headers?['Authorization'], 'Bearer jwt');
    });

    test('surfaces the REST error body rather than a generic message',
        () async {
      // This host answers a rejected token with a top-level `error` object.
      stubPlayedPages(<Response<dynamic>>[
        makeResponse(<String, dynamic>{
          'error': <String, dynamic>{'message': 'invalid token'},
        }),
      ]);

      expect(
        () => client.fetchPlayedGames(accessToken: 'stale'),
        throwsA(
          isA<PsnApiException>().having(
            (PsnApiException e) => e.message,
            'message',
            'invalid token',
          ),
        ),
      );
    });

    test('refuses an empty token without spending a request', () async {
      expect(
        () => client.fetchPlayedGames(accessToken: ' '),
        throwsA(isA<PsnApiException>()),
      );
      verifyNever(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ));
    });
  });
}
