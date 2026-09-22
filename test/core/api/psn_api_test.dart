import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/psn_api.dart';

import '../../helpers/test_helpers.dart';

/// `fetchLibraryTitles` is the seam where the two halves of a PlayStation
/// library meet. They come from different hosts, so a failure in one must not
/// cost the user the other — and only a total failure is worth an error.
void main() {
  late MockDio dio;
  late PsnApi api;

  setUpAll(registerAllFallbacks);

  setUp(() {
    dio = MockDio();
    api = PsnApi(authDio: dio, libraryDio: dio);
  });

  Map<String, dynamic> purchases(List<String> names) => <String, dynamic>{
        'data': <String, dynamic>{
          'purchasedTitlesRetrieve': <String, dynamic>{
            'games': <Map<String, dynamic>>[
              for (final String name in names)
                <String, dynamic>{'name': name, 'titleId': 'PPSA_$name'},
            ],
          },
        },
      };

  Map<String, dynamic> played(List<String> names) => <String, dynamic>{
        'titles': <Map<String, dynamic>>[
          for (final String name in names)
            <String, dynamic>{'name': name, 'titleId': 'CUSA_$name'},
        ],
      };

  /// Dispatches by URL, since both halves share one client: the play history is
  /// the only call that leaves the store's host.
  void stubLibrary({
    Map<String, dynamic>? purchasedBody,
    Map<String, dynamic>? playedBody,
    bool purchasedFails = false,
    bool playedFails = false,
    int purchasedStatus = 200,
    int playedStatus = 200,
  }) {
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((Invocation invocation) async {
      final String path = invocation.positionalArguments.first as String;
      final bool isPlayHistory = path.contains('gamelist');
      final RequestOptions options = RequestOptions(path: path);

      if (isPlayHistory) {
        if (playedFails) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'play history host down',
          );
        }
        return Response<dynamic>(
          data: playedBody,
          statusCode: playedStatus,
          requestOptions: options,
        );
      }
      if (purchasedFails) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            statusCode: purchasedStatus,
            requestOptions: options,
          ),
        );
      }
      return Response<dynamic>(
        data: purchasedBody,
        statusCode: purchasedStatus,
        requestOptions: options,
      );
    });
  }

  /// Names only, for the assertions that do not care about extra spellings.
  Future<List<String>> namesOf({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) async =>
      (await api.fetchLibraryTitles(accessToken: accessToken, onPage: onPage))
          .map((PsnLibraryTitle title) => title.name)
          .toList();

  test('merges what was bought and what was played, purchases first',
      () async {
    stubLibrary(
      purchasedBody: purchases(<String>['God of War', 'Bloodborne']),
      playedBody: played(<String>['Hogwarts Legacy', 'Bloodborne']),
    );

    final List<String> names = await namesOf(accessToken: 'jwt');

    // A title owned *and* played is one line, and the purchase spelling wins.
    expect(
      names,
      <String>['God of War', 'Bloodborne', 'Hogwarts Legacy'],
    );
  });

  test('a PlayStation Plus title reaches the library without being bought',
      () async {
    // The reported bug: played through the subscription, never purchased, so
    // the purchase half knows nothing about it.
    stubLibrary(
      purchasedBody: purchases(<String>['God of War']),
      playedBody: played(<String>['霍格沃茨之遗']),
    );

    final List<String> names = await namesOf(accessToken: 'jwt');

    expect(names, contains('霍格沃茨之遗'));
  });

  test('keeps the half that worked when the play history host fails',
      () async {
    stubLibrary(
      purchasedBody: purchases(<String>['God of War']),
      playedFails: true,
    );

    final List<String> names = await namesOf(accessToken: 'jwt');

    expect(names, <String>['God of War']);
  });

  test('keeps the purchases when the play history is refused', () async {
    stubLibrary(
      purchasedBody: purchases(<String>['God of War']),
      playedBody: <String, dynamic>{
        'error': <String, dynamic>{'message': 'invalid token'},
      },
    );

    final List<String> names = await namesOf(accessToken: 'jwt');

    expect(names, <String>['God of War']);
  });

  test('keeps the play history when the purchase list fails', () async {
    stubLibrary(
      purchasedFails: true,
      purchasedStatus: 401,
      playedBody: played(<String>['Hogwarts Legacy']),
    );

    final List<String> names = await namesOf(accessToken: 'jwt');

    expect(names, <String>['Hogwarts Legacy']);
  });

  test('raises the first failure when neither half produced a name', () async {
    stubLibrary(purchasedFails: true, purchasedStatus: 401, playedFails: true);

    expect(
      () => namesOf(accessToken: 'jwt'),
      throwsA(
        isA<PsnApiException>().having(
          (PsnApiException e) => e.message,
          'message',
          contains('Sign in again'),
        ),
      ),
    );
  });

  test('an empty account is not an error', () async {
    stubLibrary(purchasedBody: purchases(<String>[]), playedBody: played(<String>[]));

    expect(await namesOf(accessToken: 'jwt'), isEmpty);
  });

  test('reports progress for both halves', () async {
    stubLibrary(
      purchasedBody: purchases(<String>['A', 'B']),
      playedBody: played(<String>['C']),
    );

    final List<int> seen = <int>[];
    await namesOf(accessToken: 'jwt', onPage: seen.add);

    // Never goes backwards, and ends on the merged total.
    expect(seen.last, 3);
  });
}
