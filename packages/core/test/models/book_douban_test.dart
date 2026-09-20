import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:test/test.dart';

/// The by-ISBN record, trimmed to the fields the parser reads. Douban's
/// `press`, `pubdate`, `pages` and `price` are all single-element lists, and
/// the response never echoes the ISBN back.
Map<String, dynamic> isbnRecord({Map<String, dynamic> overrides = const <String, dynamic>{}}) {
  return <String, dynamic>{
    'id': '36892731',
    'title': '三体',
    'author': <dynamic>['刘慈欣'],
    'translator': <dynamic>[],
    'press': <dynamic>['重庆出版社'],
    'pubdate': <dynamic>['2021-1-1'],
    'pages': <dynamic>['300'],
    'price': <dynamic>['23.00元'],
    'rating': <String, dynamic>{
      'count': 44,
      'max': 10,
      'star_count': 4.5,
      'value': 9.4,
    },
    'intro': '第一段。\n第二段。',
    'cover_url': 'https://img3.doubanio.com/view/subject/l/public/s34863232.jpg',
    'url': 'https://book.douban.com/subject/36892731/',
    'tags': <dynamic>[
      <String, dynamic>{'name': '科幻', 'count': 1234},
      <String, dynamic>{'name': '中国文学', 'count': 567},
    ],
    ...overrides,
  };
}

/// A search row wraps the record in `target` and flattens author / year /
/// publisher into `card_subtitle`; it carries far fewer fields.
Map<String, dynamic> searchRow({Map<String, dynamic> overrides = const <String, dynamic>{}}) {
  return <String, dynamic>{
    'layout': 'subject',
    'target_id': '2567698',
    'target_type': 'book',
    'type_name': '图书',
    'target': <String, dynamic>{
      'id': '2567698',
      'title': '三体',
      'abstract': '“地球往事”三部曲之一',
      'card_subtitle': '刘慈欣 / 2008 / 重庆出版社',
      'cover_url':
          'https://img1.doubanio.com/view/subject/m/public/s2768378.jpg',
      'rating': <String, dynamic>{
        'count': 518182,
        'max': 10,
        'star_count': 4.5,
        'value': 8.9,
      },
      'uri': 'douban://douban.com/book/2567698',
      ...overrides,
    },
  };
}

void main() {
  group('Book.fromDoubanItem', () {
    test('maps the by-ISBN record', () {
      final Book book =
          Book.fromDoubanItem(isbnRecord(), isbn: '9787536692930');

      expect(book.source, DataSource.douban);
      expect(book.id, '36892731');
      expect(book.nativeId, '36892731');
      expect(book.title, '三体');
      expect(book.authors, <String>['刘慈欣']);
      expect(book.publishers, <String>['重庆出版社']);
      expect(book.publishYear, 2021);
      expect(book.pageCount, 300);
      expect(book.isbn13, '9787536692930');
      expect(book.isbn10, isNull);
      expect(
        book.coverUrl,
        'https://img3.doubanio.com/view/subject/l/public/s34863232.jpg',
      );
      expect(book.externalUrl, 'https://book.douban.com/subject/36892731/');
    });

    test('keeps rating on its native 0-10 scale', () {
      final Book book = Book.fromDoubanItem(isbnRecord());

      // 9.4 is already this app's scale; doubling it would read as 18.8.
      expect(book.rating, 9.4);
      expect(book.ratingCount, 44);
    });

    test('leaves an absent rating null rather than zero', () {
      final Book book = Book.fromDoubanItem(isbnRecord(
        overrides: <String, dynamic>{
          'rating': <String, dynamic>{'count': 0, 'max': 10, 'value': 0},
        },
      ));

      expect(book.rating, isNull);
    });

    test('stores an ISBN-10 in isbn10, not isbn13', () {
      final Book book = Book.fromDoubanItem(isbnRecord(), isbn: '7536692935');

      expect(book.isbn10, '7536692935');
      expect(book.isbn13, isNull);
    });

    test('accepts a hyphenated ISBN from the caller', () {
      final Book book =
          Book.fromDoubanItem(isbnRecord(), isbn: '978-7-5366-9293-0');

      expect(book.isbn13, '9787536692930');
    });

    test('reads the tag objects as subjects', () {
      final Book book = Book.fromDoubanItem(isbnRecord());

      expect(book.subjects, <String>['科幻', '中国文学']);
    });

    test('maps a search row whose record hides under target', () {
      final Book book = Book.fromDoubanItem(searchRow());

      expect(book.nativeId, '2567698');
      expect(book.title, '三体');
      expect(book.rating, 8.9);
      expect(book.ratingCount, 518182);
      // The row has no `intro`, only the one-line abstract.
      expect(book.description, '“地球往事”三部曲之一');
      expect(
        book.coverUrl,
        'https://img1.doubanio.com/view/subject/m/public/s2768378.jpg',
      );
    });

    test('recovers author, year and publisher from card_subtitle', () {
      final Book book = Book.fromDoubanItem(searchRow());

      expect(book.authors, <String>['刘慈欣']);
      expect(book.publishYear, 2008);
      expect(book.publishers, <String>['重庆出版社']);
    });

    test('does not mistake a year-only subtitle for a publisher', () {
      final Book book = Book.fromDoubanItem(searchRow(
        overrides: <String, dynamic>{'card_subtitle': '刘慈欣 / 2008'},
      ));

      expect(book.publishers, isEmpty);
      expect(book.publishYear, 2008);
    });

    test('builds a subject URL when the row carries none', () {
      final Book book = Book.fromDoubanItem(searchRow());

      expect(book.externalUrl, 'https://book.douban.com/subject/2567698/');
    });

    test('throws when the row has no subject id', () {
      expect(
        () => Book.fromDoubanItem(<String, dynamic>{'title': '三体'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
