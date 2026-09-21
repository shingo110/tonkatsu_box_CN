import 'package:core/models/book.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/douban/douban_http_client.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';
import 'package:tonkatsu_box/core/api/host_rate_limiter.dart';
import 'package:tonkatsu_box/shared/constants/douban_defaults.dart';

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

  Map<String, dynamic> searchRow(String id, {String title = '三体'}) =>
      <String, dynamic>{
        'target': <String, dynamic>{
          'id': id,
          'title': title,
          'card_subtitle': '刘慈欣 / 2008 / 重庆出版社',
          'rating': <String, dynamic>{'count': 518182, 'max': 10, 'value': 8.9},
        },
      };

  Map<String, dynamic> searchPage(List<dynamic> items, {int total = 269}) =>
      <String, dynamic>{
        'total': total,
        'start': 0,
        'count': 20,
        'banned': '',
        'items': items,
      };

  Map<String, dynamic> isbnRecord() => <String, dynamic>{
        'id': '36892731',
        'title': '三体',
        'author': <dynamic>['刘慈欣'],
        'press': <dynamic>['重庆出版社'],
        'rating': <String, dynamic>{'count': 44, 'max': 10, 'value': 9.4},
      };

  DioException dioError({int? statusCode, DioExceptionType? type, Object? error}) {
    return DioException(
      requestOptions: RequestOptions(path: ''),
      type: type ?? DioExceptionType.badResponse,
      error: error,
      response: statusCode == null
          ? null
          : Response<dynamic>(
              statusCode: statusCode,
              requestOptions: RequestOptions(path: ''),
            ),
    );
  }

  group('isDoubanIsbn', () {
    test('accepts an ISBN-13 and an ISBN-10', () {
      expect(isDoubanIsbn('9787536692930'), isTrue);
      expect(isDoubanIsbn('7536692935'), isTrue);
    });

    test('ignores hyphens and spaces', () {
      expect(isDoubanIsbn('978-7-5366-9293-0'), isTrue);
      expect(isDoubanIsbn('7 536 692 935'), isTrue);
    });

    test('accepts an ISBN-10 ending in X', () {
      expect(isDoubanIsbn('043942089X'), isTrue);
    });

    test('rejects a title and a wrong digit count', () {
      expect(isDoubanIsbn('三体'), isFalse);
      expect(isDoubanIsbn('97875366929'), isFalse);
      expect(isDoubanIsbn('97875366929301'), isFalse);
    });

    test('normaliseDoubanIsbn strips separators', () {
      expect(normalizeDoubanIsbn('978-7-5366-9293-0'), '9787536692930');
    });
  });

  group('searchBooks', () {
    test('parses items and reports the page count', () async {
      stubGet(searchPage(<dynamic>[searchRow('2567698')]));

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
      expect(books.single.title, '三体');
      expect(hasMore, isTrue);
      expect(totalPages, 14);
      final List<dynamic> captured = captureGet();
      expect(captured[0], '/api/v2/search/book');
      expect(
        captured[1],
        <String, dynamic>{'q': '三体', 'start': 0, 'count': 20},
      );
    });

    test('turns the page number into a start offset', () async {
      stubGet(searchPage(<dynamic>[searchRow('2567698')]));

      await api.searchBooks(query: '三体', page: 3);

      final Map<String, dynamic> params =
          captureGet()[1] as Map<String, dynamic>;
      expect(params['start'], 40);
    });

    test('ends the run on the last page', () async {
      stubGet(searchPage(<dynamic>[searchRow('2567698')], total: 21));

      final (_, bool hasMore, _) =
          await api.searchBooks(query: '三体', page: 2);

      expect(hasMore, isFalse);
    });

    test('reads an empty body as an empty page', () async {
      stubGet('');

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, isEmpty);
      expect(hasMore, isFalse);
      expect(totalPages, 0);
    });

    test('skips a row without an id', () async {
      stubGet(searchPage(<dynamic>[
        searchRow('2567698'),
        <String, dynamic>{'target': <String, dynamic>{'title': '无名'}},
      ]));

      final (List<Book> books, _, _) = await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
    });
  });

  group('ISBN path', () {
    test('asks the by-ISBN endpoint and stores the ISBN', () async {
      stubGet(isbnRecord());

      final Book? book = await api.getBookByIsbn('978-7-5366-9293-0');

      expect(book, isNotNull);
      expect(book!.isbn13, '9787536692930');
      expect(captureGet()[0], '/api/v2/book/isbn/9787536692930');
    });

    test('getBook asks the by-id endpoint', () async {
      stubGet(isbnRecord());

      final Book? book = await api.getBook('36892731');

      expect(book!.nativeId, '36892731');
      expect(captureGet()[0], '/api/v2/book/36892731');
    });

    test('a missing subject answers null rather than throwing', () async {
      stubGet(<String, dynamic>{'msg': 'not found'});

      expect(await api.getBook('1'), isNull);
    });
  });

  group('without credentials', () {
    test('skips the call rather than sending it unsigned', () async {
      final DoubanApi bare = DoubanApi(dio: mockDio);

      final (List<Book> books, bool hasMore, _) =
          await bare.searchBooks(query: '三体');

      expect(books, isEmpty);
      expect(hasMore, isFalse);
      expect(await bare.getBook('1'), isNull);
      verifyNever(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ));
    });
  });

  group('error mapping', () {
    Future<String> messageFor(DioException error) async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(error);

      try {
        await api.searchBooks(query: '三体');
      } on DoubanApiException catch (e) {
        return e.message;
      }
      return 'no exception';
    }

    test('403 names the pair and the wait', () async {
      expect(
        await messageFor(dioError(statusCode: 403)),
        contains('Check the API key and secret'),
      );
    });

    test('401 reads as a rejected signature', () async {
      expect(
        await messageFor(dioError(statusCode: 401)),
        contains('rejected the request signature'),
      );
    });

    test('an open breaker keeps its own wording', () async {
      expect(
        await messageFor(dioError(
          error: const HostCooldownException('douban.com', Duration(minutes: 3)),
        )),
        contains('Rate limit exceeded for douban.com'),
      );
    });

    test('offline reads as a connection error', () async {
      expect(
        await messageFor(dioError(type: DioExceptionType.connectionError)),
        'No internet connection',
      );
    });

    test('carries a redacted detail', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 403));

      await expectLater(
        api.searchBooks(query: '三体'),
        throwsA(
          isA<DoubanApiException>().having(
            (DoubanApiException e) => e.detail,
            'detail',
            allOf(contains('API: Douban'), contains('Status: 403')),
          ),
        ),
      );
    });
  });

  group('DoubanAuthInterceptor', () {
    test('signs the request path with the pair', () {
      // The secret half is the shipped pair's, because the vector asserted
      // below is the one the Python reference prints for it. The key half is
      // arbitrary — it does not enter the signature.
      final DoubanAuthInterceptor auth = DoubanAuthInterceptor(
        now: () => DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      )..setCredentials('mykey', DoubanDefaults.apiSecret);

      final RequestOptions options =
          RequestOptions(path: '/api/v2/book/isbn/9787536692930');
      auth.onRequest(options, RequestInterceptorHandler());

      expect(options.queryParameters['apiKey'], 'mykey');
      expect(options.queryParameters['_ts'], 1700000000);
      // The same vector the Python reference in probe/ produces.
      expect(options.queryParameters['_sig'], 'g9+l253xM80riZQoEdnRsPFqgAs=');
    });

    test('leaves the request unsigned without a pair', () {
      final DoubanAuthInterceptor auth = DoubanAuthInterceptor();

      final RequestOptions options =
          RequestOptions(path: '/api/v2/search/book');
      auth.onRequest(options, RequestInterceptorHandler());

      expect(options.queryParameters, isEmpty);
    });
  });
}
