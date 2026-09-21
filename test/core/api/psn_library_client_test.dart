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
}
