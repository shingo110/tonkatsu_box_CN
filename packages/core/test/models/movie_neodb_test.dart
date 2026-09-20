import 'package:core/models/data_source.dart';
import 'package:core/models/movie.dart';
import 'package:core/utils/stable_id.dart';
import 'package:test/test.dart';

Map<String, dynamic> item([
  Map<String, dynamic> overrides = const <String, dynamic>{},
]) {
  return <String, dynamic>{
    'uuid': '4RQwAeTa5E2DKPPbFt4UVJ',
    'id': 'https://neodb.social/movie/4RQwAeTa5E2DKPPbFt4UVJ',
    'url': '/movie/4RQwAeTa5E2DKPPbFt4UVJ',
    'api_url': '/api/movie/4RQwAeTa5E2DKPPbFt4UVJ',
    'category': 'movie',
    'type': 'Movie',
    'display_title': 'Farewell My Concubine',
    'title': 'Farewell My Concubine',
    'orig_title': '霸王别姬',
    'localized_title': <Map<String, dynamic>>[
      <String, dynamic>{'lang': 'zh-cn', 'text': '霸王别姬'},
      <String, dynamic>{'lang': 'en', 'text': 'Farewell My Concubine'},
    ],
    'localized_description': <Map<String, dynamic>>[
      <String, dynamic>{'lang': 'zh-cn', 'text': '段小楼与程蝶衣是打小儿一起长大的师兄弟。'},
    ],
    'description': 'Two boys meet at an opera training school in Peking.',
    'brief': 'Two boys meet at an opera training school in Peking.',
    'cover_image_url': 'https://neodb.social/m/item/movie/cover.webp',
    'rating': 9.5,
    'rating_count': 2796,
    'tags': <String>['1993', '中国', '剧情'],
    'genre': <String>['drama', 'romance'],
    'year': 1993,
    'release_date': '1993-01-01',
    'length': 10260,
    'duration': '2h 51m',
    'imdb': 'tt0106332',
    ...overrides,
  };
}

void main() {
  group('Movie.fromNeoDBItem', () {
    test('stamps NeoDB as the source', () {
      expect(Movie.fromNeoDBItem(item()).source, DataSource.neodb);
    });

    test('folds the uuid through fnv1a64 to keep the integer id', () {
      final Movie movie = Movie.fromNeoDBItem(item());

      expect(movie.tmdbId, isNot(0));
      expect(movie.tmdbId, fnv1a64('4RQwAeTa5E2DKPPbFt4UVJ'));
    });

    test('prefers the zh-cn title over the English display_title', () {
      expect(Movie.fromNeoDBItem(item()).title, '霸王别姬');
    });

    test('keeps orig_title only when it differs from the title', () {
      expect(Movie.fromNeoDBItem(item()).originalTitle, isNull);

      final Movie localizedOnly = Movie.fromNeoDBItem(item(<String, dynamic>{
        'localized_title': <Map<String, dynamic>>[
          <String, dynamic>{'lang': 'zh-cn', 'text': '霸王别姬'},
        ],
        'orig_title': 'Ba wang bie ji',
      }));

      expect(localizedOnly.originalTitle, 'Ba wang bie ji');
    });

    test('reads the rating on NeoDB\'s own 1-10 scale, undoubled', () {
      // NeoDB scores out of 10; doubling it would read as 19.0.
      expect(Movie.fromNeoDBItem(item()).rating, 9.5);
    });

    test('treats a zero rating as unrated', () {
      expect(
        Movie.fromNeoDBItem(item(<String, dynamic>{'rating': 0})).rating,
        isNull,
      );
    });

    test('turns the length in seconds into whole minutes', () {
      expect(Movie.fromNeoDBItem(item()).runtime, 171);
    });

    test('falls back to the tags year when the row carries no year', () {
      // Search rows omit `year` entirely — only the detail response has it.
      final Movie movie = Movie.fromNeoDBItem(item(<String, dynamic>{
        'year': null,
        'release_date': null,
      }));

      expect(movie.releaseYear, 1993);
    });

    test('does not read a decade bucket as a year', () {
      final Movie movie = Movie.fromNeoDBItem(item(<String, dynamic>{
        'year': null,
        'tags': <String>['2020s', '中国大陆', '剧情'],
      }));

      expect(movie.releaseYear, isNull);
    });

    test('takes the Chinese synopsis from the localized array', () {
      expect(
        Movie.fromNeoDBItem(item()).overview,
        '段小楼与程蝶衣是打小儿一起长大的师兄弟。',
      );
    });

    test('maps genre slugs verbatim and nulls an empty list', () {
      expect(Movie.fromNeoDBItem(item()).genres, <String>['drama', 'romance']);
      expect(
        Movie.fromNeoDBItem(item(<String, dynamic>{'genre': <String>[]})).genres,
        isNull,
      );
    });

    test('links back to the NeoDB page', () {
      expect(
        Movie.fromNeoDBItem(item()).externalUrl,
        'https://neodb.social/movie/4RQwAeTa5E2DKPPbFt4UVJ',
      );
    });

    test('keeps the model usable when optional fields are missing', () {
      final Movie movie = Movie.fromNeoDBItem(<String, dynamic>{
        'uuid': 'abc',
        'title': 'Untitled',
      });

      expect(movie.title, 'Untitled');
      expect(movie.tmdbId, fnv1a64('abc'));
      expect(movie.rating, isNull);
      expect(movie.runtime, isNull);
      expect(movie.overview, isNull);
    });
  });
}
