import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/weread_api.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockDio mockDio;
  late WeReadApi api;

  setUpAll(registerAllFallbacks);

  setUp(() {
    mockDio = MockDio();
    api = WeReadApi(dio: mockDio);
  });

  Response<dynamic> makeResponse(dynamic data) => Response<dynamic>(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  Map<String, dynamic> bookRow(
    String bookId, {
    String title = '三体全集（全三册）',
    Object? rating = 930,
    Object? ratingCount = 295308,
  }) =>
      <String, dynamic>{
        'bookInfo': <String, dynamic>{
          'bookId': bookId,
          'title': title,
          'author': '刘慈欣',
          'cover': 'https://cdn.weread.qq.com/cover/$bookId.jpg',
          'intro': '每个人的书架上都该有套《三体》！',
          'publisher': '重庆出版社',
          'newRating': rating,
          'newRatingCount': ratingCount,
          'deepLink': 'https://weread.qq.com/book-detail?type=1&v=$bookId',
        },
        'searchIdx': 1,
        'readingCount': 9933,
      };

  /// The real answer always carries `totalCount` and `hasMore`, neither of
  /// which the parser trusts — they are here so a regression that starts
  /// trusting them would be caught.
  Map<String, dynamic> page(List<dynamic> rows) => <String, dynamic>{
        'books': rows,
        'totalCount': 59,
        'hasMore': 1,
      };

  DioException dioError({int? statusCode, DioExceptionType? type}) {
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

  List<dynamic> captureGet() {
    return verify(() => mockDio.get<dynamic>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
  }

  group('searchBooks', () {
    test('parses rows and asks with an offset of zero on page one', () async {
      stubGet(page(<dynamic>[bookRow('695233')]));

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
      expect(books.single.title, '三体全集（全三册）');
      expect(books.single.source, DataSource.weread);
      expect(books.single.nativeId, '695233');
      expect(hasMore, isTrue);
      expect(totalPages, 2);
      // Captured once: `verify` consumes the call, so a second call would
      // find nothing left to match.
      final List<dynamic> captured = captureGet();
      expect(captured[0], 'web/search/global');
      expect(
        captured[1],
        <String, dynamic>{'keyword': '三体', 'maxIdx': 0, 'count': 20},
      );
    });

    test('turns the page number into a maxIdx offset', () async {
      stubGet(page(<dynamic>[bookRow('695233')]));

      await api.searchBooks(query: '三体', page: 3);

      final Map<String, dynamic> params =
          captureGet()[1] as Map<String, dynamic>;
      expect(params['maxIdx'], 40);
      expect(params['count'], 20);
    });

    test('an empty page ends the run', () async {
      stubGet(page(<dynamic>[]));

      final (List<Book> books, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体', page: 3);

      expect(books, isEmpty);
      expect(hasMore, isFalse);
      expect(totalPages, 3);
    });

    test('ignores totalCount and hasMore, which the API misreports', () async {
      // 10087 shown against 20 rows would be nonsense, and hasMore never
      // leaves 1 — paging follows the offset ceiling instead.
      stubGet(<String, dynamic>{
        'books': <dynamic>[bookRow('695233')],
        'totalCount': 10087,
        'hasMore': 1,
      });

      final (List<Book> _, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体');

      expect(hasMore, isTrue);
      expect(totalPages, 2);
    });

    test('stops at the offset ceiling however many rows arrive', () async {
      stubGet(page(<dynamic>[bookRow('695233')]));

      final (List<Book> _, bool hasMore, int totalPages) =
          await api.searchBooks(query: '三体', page: kWeReadMaxOffset ~/ 20);

      expect(hasMore, isTrue);
      expect(totalPages, kWeReadMaxOffset ~/ 20 + 1);

      final (List<Book> _, bool pastCeiling, _) =
          await api.searchBooks(query: '三体', page: kWeReadMaxOffset ~/ 20 + 1);

      expect(pastCeiling, isFalse);
    });

    test('reads an empty body as an empty page', () async {
      stubGet('');

      final (List<Book> books, bool hasMore, _) =
          await api.searchBooks(query: '三体');

      expect(books, isEmpty);
      expect(hasMore, isFalse);
    });

    test('skips a malformed row without failing the page', () async {
      stubGet(page(<dynamic>[
        bookRow('695233'),
        'not an object',
        <String, dynamic>{'searchIdx': 2},
      ]));

      final (List<Book> books, _, _) = await api.searchBooks(query: '三体');

      expect(books, hasLength(1));
      expect(books.single.nativeId, '695233');
    });

    test('carries a redacted debug detail on failure', () async {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(dioError(statusCode: 500));

      await expectLater(
        api.searchBooks(query: '三体'),
        throwsA(
          isA<WeReadApiException>().having(
            (WeReadApiException e) => e.detail,
            'detail',
            allOf(contains('API: WeRead'), contains('Status: 500')),
          ),
        ),
      );
    });
  });

  group('findByNativeId', () {
    test('searches the title and matches the stored bookId', () async {
      stubGet(page(<dynamic>[
        bookRow('111', title: '三体：史上最称职的面壁者'),
        bookRow('695233'),
      ]));

      final Book? book = await api.findByNativeId(
        title: '三体全集（全三册）',
        nativeId: '695233',
      );

      expect(book, isNotNull);
      expect(book!.nativeId, '695233');
      final Map<String, dynamic> params =
          captureGet()[1] as Map<String, dynamic>;
      expect(params['keyword'], '三体全集（全三册）');
      expect(params['maxIdx'], 0);
    });

    test('returns null when the title no longer surfaces that bookId', () async {
      stubGet(page(<dynamic>[bookRow('111')]));

      expect(
        await api.findByNativeId(title: '三体', nativeId: '695233'),
        isNull,
      );
    });

    test('does not call out for a blank title', () async {
      stubGet(page(<dynamic>[]));

      expect(await api.findByNativeId(title: '   ', nativeId: 'x'), isNull);
      verifyNever(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ));
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
      } on WeReadApiException catch (e) {
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

    test('a 400 reads as a rejected request', () async {
      expect(await messageFor(null, 400), 'WeRead rejected the request');
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
        'Failed to search WeRead',
      );
    });

    test('toString names the exception', () {
      expect(
        const WeReadApiException('boom', statusCode: 500).toString(),
        'WeReadApiException: boom (status: 500)',
      );
    });
  });
}
