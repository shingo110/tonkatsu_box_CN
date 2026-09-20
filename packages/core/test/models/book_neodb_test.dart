import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:test/test.dart';

Map<String, dynamic> item([
  Map<String, dynamic> overrides = const <String, dynamic>{},
]) {
  return <String, dynamic>{
    'uuid': '7OGqnJkxiQZImAxD9aAgMr',
    'id': 'https://neodb.social/book/7OGqnJkxiQZImAxD9aAgMr',
    'url': '/book/7OGqnJkxiQZImAxD9aAgMr',
    'api_url': '/api/book/7OGqnJkxiQZImAxD9aAgMr',
    'category': 'book',
    'display_title': '三体',
    'title': '三体',
    'orig_title': '三体',
    'localized_title': <Map<String, dynamic>>[
      <String, dynamic>{'lang': 'zh-cn', 'text': '三体'},
    ],
    'description': '文化大革命如火如荼进行的同时。',
    'brief': '短简介',
    'cover_image_url': 'https://neodb.social/m/item/cover.jpg',
    'rating': 8.6,
    'rating_count': 1537,
    'tags': <String>['科幻', '中国科幻', '刘慈欣', '经典'],
    'author': <String>['Cixin Liu', 'Liu Cixin', '刘慈欣'],
    'translator': <String>[],
    'language': <String>['zh'],
    'publisher': <String>['重庆出版社'],
    'pub_house': '重庆出版社',
    'pub_year': 2008,
    'pages': '302',
    'isbn': '9787536692930',
    'series': '“地球往事”三部曲',
    ...overrides,
  };
}

void main() {
  group('Book.fromNeoDBItem', () {
    test('stamps NeoDB as the source and leaves the kind prose', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.source, DataSource.neodb);
      expect(book.nativeId, '7OGqnJkxiQZImAxD9aAgMr');
      expect(book.isComic, isFalse);
    });

    test('folds the uuid through fnv1a64 to keep the numeric id', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.id, isNot('7OGqnJkxiQZImAxD9aAgMr'));
      expect(() => int.parse(book.id), returnsNormally);
      expect(book.id, book.externalIdInt.toString());
    });

    test('takes the Chinese title from the localized array', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': <Map<String, dynamic>>[
          <String, dynamic>{'lang': 'en', 'text': 'The Three-Body Problem'},
          <String, dynamic>{'lang': 'zh-cn', 'text': '三体'},
        ],
      }));

      expect(book.title, '三体');
    });

    test('ranks the zh-cn rendering above every other Chinese tag', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': <Map<String, dynamic>>[
          <String, dynamic>{'lang': 'zh-tw', 'text': '三體'},
          <String, dynamic>{'lang': 'zh-cn', 'text': '三体'},
        ],
      }));

      expect(book.title, '三体');
    });

    test('falls back to display_title when nothing is Chinese', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': <Map<String, dynamic>>[
          <String, dynamic>{'lang': 'af', 'text': 'Norwegian Wood'},
        ],
        'display_title': '挪威的森林',
      }));

      expect(book.title, '挪威的森林');
    });

    test('falls back to title when display_title is absent', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': null,
        'display_title': null,
        'title': '只有 title',
      }));

      expect(book.title, '只有 title');
    });

    test('survives a payload with no title at all', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': null,
        'display_title': '',
        'title': null,
        'orig_title': null,
      }));

      expect(book.title, 'Unknown');
    });

    test('keeps the original title only when it differs', () {
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{'orig_title': '三体'}))
            .originalTitle,
        isNull,
      );
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{'orig_title': 'Remains'}))
            .originalTitle,
        'Remains',
      );
    });

    test('prefers Chinese author forms over the romanized duplicates', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.authors, <String>['刘慈欣']);
    });

    test('keeps a romanized author list that offers no Chinese form', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'author': <String>['Haruki Murakami'],
      }));

      expect(book.authors, <String>['Haruki Murakami']);
    });

    test('strips empty author entries', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'author': <String>['', '刘慈欣', ''],
      }));

      expect(book.authors, <String>['刘慈欣']);
    });

    test('leaves the rating on NeoDB’s own 0-10 scale', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.rating, 8.6);
      expect(book.ratingCount, 1537);
    });

    test('reads an integer rating too', () {
      expect(Book.fromNeoDBItem(item(<String, dynamic>{'rating': 7})).rating,
          7.0);
    });

    test('treats a zero rating as unrated', () {
      expect(Book.fromNeoDBItem(item(<String, dynamic>{'rating': 0})).rating,
          isNull);
    });

    test('accepts absent ratings', () {
      expect(Book.fromNeoDBItem(item(<String, dynamic>{'rating': null})).rating,
          isNull);
    });

    test('parses a page count that arrives as a string', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.pageCount, 302);
    });

    test('parses a page count that arrives as a number', () {
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{'pages': 176})).pageCount,
        176,
      );
    });

    test('leaves an unusable page count null', () {
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{'pages': null})).pageCount,
        isNull,
      );
    });

    test('sorts an ISBN into its 13-digit field', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.isbn13, '9787536692930');
      expect(book.isbn10, isNull);
    });

    test('sorts an ISBN into its 10-digit field', () {
      final Book book = Book.fromNeoDBItem(
        item(<String, dynamic>{'isbn': '7536692930'}),
      );

      expect(book.isbn10, '7536692930');
      expect(book.isbn13, isNull);
    });

    test('drops an ISBN of an unexpected length', () {
      final Book book = Book.fromNeoDBItem(
        item(<String, dynamic>{'isbn': '123'}),
      );

      expect(book.isbn10, isNull);
      expect(book.isbn13, isNull);
    });

    test('takes the publisher list over the single pub_house string', () {
      expect(Book.fromNeoDBItem(item()).publishers, <String>['重庆出版社']);
    });

    test('falls back to pub_house when the list is empty', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'publisher': <String>[],
        'pub_house': '新星出版社',
      }));

      expect(book.publishers, <String>['新星出版社']);
    });

    test('carries publish year, series, cover and languages', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.publishYear, 2008);
      expect(book.series, '“地球往事”三部曲');
      expect(book.coverUrl, 'https://neodb.social/m/item/cover.jpg');
      expect(book.languages, <String>['zh']);
    });

    test('turns Chinese tags into subjects', () {
      final Book book = Book.fromNeoDBItem(item());

      expect(book.subjects, <String>['科幻', '中国科幻', '刘慈欣', '经典']);
    });

    test('deduplicates subjects case-insensitively', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'tags': <String>['科幻', '科幻'],
      }));

      expect(book.subjects, <String>['科幻']);
    });

    test('caps runaway tag lists', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'tags': <String>[
          for (int i = 0; i < 40; i++) '标签$i',
        ],
      }));

      expect(book.subjects, hasLength(15));
    });

    test('uses the absolute id url when present', () {
      expect(
        Book.fromNeoDBItem(item()).externalUrl,
        'https://neodb.social/book/7OGqnJkxiQZImAxD9aAgMr',
      );
    });

    test('builds the url from the relative path when the id is absent', () {
      final Book book = Book.fromNeoDBItem(item(<String, dynamic>{
        'id': null,
      }));

      expect(
        book.externalUrl,
        'https://neodb.social/book/7OGqnJkxiQZImAxD9aAgMr',
      );
    });

    test('prefers the description and falls back to brief', () {
      expect(
        Book.fromNeoDBItem(item()).description,
        '文化大革命如火如荼进行的同时。',
      );
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{'description': null}))
            .description,
        '短简介',
      );
    });

    test('leaves an empty description null', () {
      expect(
        Book.fromNeoDBItem(item(<String, dynamic>{
          'description': '',
          'brief': '',
        })).description,
        isNull,
      );
    });

    test('survives an empty payload', () {
      final Book book = Book.fromNeoDBItem(<String, dynamic>{});

      expect(book.title, 'Unknown');
      expect(book.authors, isEmpty);
      expect(book.subjects, isEmpty);
      expect(book.rating, isNull);
      expect(book.coverUrl, isNull);
      expect(book.externalUrl, isNull);
    });
  });
}
