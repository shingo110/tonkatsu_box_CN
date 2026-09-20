import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/neodb_api.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late NeoDBApi api;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    api = NeoDBApi(dio: mockDio);
  });

  Response<dynamic> makeResponse(dynamic data) => Response<dynamic>(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  Map<String, dynamic> itemRow(String uuid) => <String, dynamic>{
        'uuid': uuid,
        'id': 'https://neodb.social/book/$uuid',
        'url': '/book/$uuid',
        'category': 'book',
        'display_title': '三体',
        'localized_title': <Map<String, dynamic>>[
          <String, dynamic>{'lang': 'zh-cn', 'text': '三体'},
        ],
        'description': '简介',
        'rating': 8.6,
        'rating_count': 1537,
        'tags': <String>['科幻'],
      };

  Map<String, dynamic> page(List<dynamic> rows, {int pages = 2}) =>
      <String, dynamic>{'data': rows, 'pages': pages, 'count': 40};

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

  void stubGet(dynamic data) {
    when(() => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => makeResponse(data));
  }

  /// Captures [path, queryParameters] of the last GET — mocktail keeps both
  /// in call order, and there is only one positional argument here.
  List<dynamic> captureGet() {
    return verify(() => mockDio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
  }

  group('searchBooks', () {
    test('parses rows and derives hasMore from pages', () async {
      stubGet(page(<dynamic>[itemRow('a'), itemRow('b')], pages: 4));

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, hasLength(2));
      expect(books.first.title, '三体');
      expect(books.first.source, DataSource.neodb);
      expect(hasMore, isTrue);
      expect(totalPages, 4);
    });

    test('hasMore is false on the last page', () async {
      stubGet(page(<dynamic>[itemRow('a')], pages: 3));

      final (List<Book> _, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体', page: 3);

      expect(hasMore, isFalse);
      expect(totalPages, 3);
    });

    test('never derives the page count from the row count', () async {
      // Six rows on a two-page answer is normal here: pages collapse editions.
      stubGet(page(<dynamic>[
        for (int i = 0; i < 6; i++) itemRow('r$i'),
      ], pages: 2));

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, hasLength(6));
      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('defaults to one page when the API sends no count', () async {
      stubGet(<String, dynamic>{'data': <dynamic>[itemRow('a')]});

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
      expect(hasMore, isFalse);
      expect(totalPages, 1);
    });

    test('sends the keyword, book category and page', () async {
      stubGet(page(<dynamic>[]));

      await api.searchBooks(query: '三体', page: 3);

      final List<dynamic> captured = captureGet();
      expect(captured[0], 'api/catalog/search');
      expect(
        captured[1],
        <String, dynamic>{'query': '三体', 'category': 'book', 'page': 3},
      );
    });

    test('skips a malformed row without failing the page', () async {
      stubGet(page(<dynamic>[
        itemRow('a'),
        'not an object',
        42,
      ]));

      final (List<Book> books, _, _) = await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
      expect(books.single.nativeId, 'a');
    });

    test('reads a non-list data field as an empty page', () async {
      stubGet(<String, dynamic>{'data': null, 'pages': 1});

      final (List<Book> books, bool hasMore, _) =
          await api.searchBooks(query: '三体');

      expect(books, isEmpty);
      expect(hasMore, isFalse);
    });

    test('a missing keyword explains why there can be no browse', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 422));

      await expectLater(
        api.searchBooks(query: 'x'),
        throwsA(
          isA<NeoDBApiException>()
              .having((NeoDBApiException e) => e.message, 'message',
                  'NeoDB needs a search keyword')
              .having(
                (NeoDBApiException e) => e.statusCode,
                'statusCode',
                422,
              ),
        ),
      );
    });

    test('carries a redacted debug detail on failure', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 500));

      await expectLater(
        api.searchBooks(query: '三体'),
        throwsA(
          isA<NeoDBApiException>().having(
            (NeoDBApiException e) => e.detail,
            'detail',
            allOf(contains('API: NeoDB'), contains('Status: 500')),
          ),
        ),
      );
    });
  });

  group('getBookById', () {
    test('reads the category-prefixed item path', () async {
      stubGet(itemRow('7OGqnJkxiQZImAxD9aAgMr'));

      final Book? book = await api.getBookById('7OGqnJkxiQZImAxD9aAgMr');

      expect(book, isNotNull);
      expect(book!.nativeId, '7OGqnJkxiQZImAxD9aAgMr');
      expect(captureGet()[0], 'api/book/7OGqnJkxiQZImAxD9aAgMr');
    });

    test('returns null on a 404', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 404));

      expect(await api.getBookById('missing'), isNull);
    });

    test('returns null when the body is not an object', () async {
      stubGet(<dynamic>[]);

      expect(await api.getBookById('x'), isNull);
    });

    test('rethrows a transport failure as a NeoDBApiException', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
        dioError(type: DioExceptionType.connectionTimeout),
      );

      await expectLater(
        api.getBookById('x'),
        throwsA(
          isA<NeoDBApiException>().having(
            (NeoDBApiException e) => e.message,
            'message',
            'Connection timeout',
          ),
        ),
      );
    });
  });

  group('error mapping', () {
    Future<String> messageFor(DioExceptionType? type, int? status) async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: status, type: type));

      try {
        await api.searchBooks(query: 'x');
      } on NeoDBApiException catch (e) {
        return e.message;
      }
      return 'no exception';
    }

    test('429 reads as a rate limit', () async {
      expect(
        await messageFor(null, 429),
        'Rate limit exceeded. Please try again later',
      );
    });

    test('a bare 404 reads as not found', () async {
      expect(await messageFor(null, 404), 'Not found');
    });

    test('offline reads as a connection error', () async {
      expect(
        await messageFor(DioExceptionType.connectionError, null),
        'No internet connection',
      );
    });

    test('an unmapped status keeps the caller default', () async {
      expect(
        await messageFor(DioExceptionType.badResponse, 503),
        'Failed to search NeoDB',
      );
    });

    test('toString names the exception', () {
      expect(
        const NeoDBApiException('boom', statusCode: 500).toString(),
        'NeoDBApiException: boom (status: 500)',
      );
    });
  });
}
