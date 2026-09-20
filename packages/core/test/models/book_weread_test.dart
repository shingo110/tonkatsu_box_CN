import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:test/test.dart';

Map<String, dynamic> row({
  Map<String, dynamic> info = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'bookInfo': <String, dynamic>{
      'bookId': '695233',
      'title': '三体全集（全三册）',
      'author': '刘慈欣',
      'cover': 'https://cdn.weread.qq.com/cover/695233.jpg',
      'intro': '第一段。\n第二段。',
      'publisher': '重庆出版社',
      'newRating': 930,
      'newRatingCount': 295308,
      'newRatingDetail': <String, dynamic>{'title': '神作'},
      'deepLink': 'https://weread.qq.com/book-detail?type=1&v=ce032b30',
      ...info,
    },
    'searchIdx': 1,
    'readingCount': 9933,
  };
}

void main() {
  group('Book.fromWeReadItem', () {
    test('stamps WeRead as the source and leaves the kind prose', () {
      final Book book = Book.fromWeReadItem(row());

      expect(book.source, DataSource.weread);
      expect(book.nativeId, '695233');
      expect(book.id, '695233');
      expect(book.isComic, isFalse);
    });

    test('divides the 0-1000 score instead of doubling it', () {
      // 930 is shown by the store as 93.0; the app's books are out of 10.
      final Book book = Book.fromWeReadItem(row());

      expect(book.rating, 9.3);
      expect(book.ratingCount, 295308);
    });

    test('leaves an unrated book without a score', () {
      final Book book =
          Book.fromWeReadItem(row(info: <String, dynamic>{'newRating': null}));

      expect(book.rating, isNull);
    });

    test('reads a zero score as unrated rather than a rating of nothing', () {
      final Book book =
          Book.fromWeReadItem(row(info: <String, dynamic>{'newRating': 0}));

      expect(book.rating, isNull);
    });

    test('keeps the author as one display string', () {
      // The store ships a single formatted line, so splitting on spaces would
      // invent authors nobody named separately.
      final Book book = Book.fromWeReadItem(row(info: <String, dynamic>{
        'author': '曹雪芹著 无名氏续 程伟元 高鹗整理',
      }));

      expect(book.authors, <String>['曹雪芹著 无名氏续 程伟元 高鹗整理']);
    });

    test('carries a bracketed nationality through untouched', () {
      final Book book = Book.fromWeReadItem(
        row(info: <String, dynamic>{'author': '[哥]加西亚·马尔克斯'}),
      );

      expect(book.authors, <String>['[哥]加西亚·马尔克斯']);
    });

    test('keeps the intro newlines and strips nothing', () {
      final Book book = Book.fromWeReadItem(row());

      expect(book.description, '第一段。\n第二段。');
    });

    test('takes the publisher as a single-entry list', () {
      final Book book = Book.fromWeReadItem(row());

      expect(book.publishers, <String>['重庆出版社']);
    });

    test('drops an empty publisher, which web novels usually omit', () {
      final Book book = Book.fromWeReadItem(
        row(info: <String, dynamic>{'publisher': ''}),
      );

      expect(book.publishers, isEmpty);
    });

    test('links out through deepLink, the only rebuildable-free URL', () {
      final Book book = Book.fromWeReadItem(row());

      expect(
        book.externalUrl,
        'https://weread.qq.com/book-detail?type=1&v=ce032b30',
      );
    });

    test('has no link when the row carries no deepLink', () {
      final Book book = Book.fromWeReadItem(
        row(info: <String, dynamic>{'deepLink': null}),
      );

      expect(book.externalUrl, isNull);
    });

    test('throws for a row without bookInfo so the page can drop it', () {
      expect(
        () => Book.fromWeReadItem(<String, dynamic>{'searchIdx': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws for a bookInfo without a bookId', () {
      expect(
        () => Book.fromWeReadItem(row(info: <String, dynamic>{'bookId': ''})),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to Unknown when the title is missing', () {
      final Book book = Book.fromWeReadItem(
        row(info: <String, dynamic>{'title': null}),
      );

      expect(book.title, 'Unknown');
    });
  });
}
