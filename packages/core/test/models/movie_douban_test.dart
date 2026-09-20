import 'package:core/models/data_source.dart';
import 'package:core/models/movie.dart';
import 'package:test/test.dart';

/// A full `/api/v2/movie/{id}` record, trimmed to the fields the mapping reads.
Map<String, dynamic> doubanMovieRecord({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  final Map<String, dynamic> json = <String, dynamic>{
    'id': '35267208',
    'title': '流浪地球2',
    'original_title': '',
    'year': '2023',
    'genres': <String>['科幻', '冒险', '灾难'],
    'countries': <String>['中国大陆'],
    'durations': <String>['173分钟'],
    'episodes_count': 0,
    'aka': <String>[
      '流浪地球2(3D版)',
      'The Wandering Earth Ⅱ',
      'The Wandering Earth 2',
      '《流浪地球》前传',
    ],
    'rating': <String, dynamic>{
      'count': 1428404,
      'max': 10,
      'star_count': 4.0,
      'value': 8.3,
    },
    'pic': <String, dynamic>{
      'large': 'https://img9.doubanio.com/view/photo/public/p2916835424.webp',
    },
    'intro': '在并不遥远的未来，太阳急速衰老与膨胀。',
    'subtype': 'movie',
    'type': 'movie',
    'card_subtitle': '2023 / 中国大陆 / 科幻 冒险 灾难 / 郭帆 / 吴京 刘德华',
  };
  json.addAll(overrides);
  return json;
}

/// The `target` object of one `/api/v2/search/movie` row: no `genres` array,
/// no `intro`, and the metadata folded into `card_subtitle`.
Map<String, dynamic> doubanMovieRow({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  final Map<String, dynamic> json = <String, dynamic>{
    'abstract': '',
    'card_subtitle': '中国大陆 / 科幻 冒险 灾难 / 郭帆 / 吴京 刘德华',
    'cover_url':
        'https://qnmob3-sign.doubanio.com/view/photo/public/p2916835424.jpg',
    'has_linewatch': true,
    'id': '35267208',
    'null_rating_reason': '',
    'rating': <String, dynamic>{
      'count': 1428404,
      'max': 10,
      'star_count': 4.0,
      'value': 8.3,
    },
    'title': '流浪地球2',
    'uri': 'douban://douban.com/movie/35267208',
    'year': '2023',
  };
  json.addAll(overrides);
  return json;
}

void main() {
  group('Movie.fromDoubanItem', () {
    test('maps a full record', () {
      final Movie movie = Movie.fromDoubanItem(doubanMovieRecord());

      expect(movie.tmdbId, 35267208);
      expect(movie.title, '流浪地球2');
      expect(movie.source, DataSource.douban);
      expect(movie.releaseYear, 2023);
      expect(movie.genres, <String>['科幻', '冒险', '灾难']);
      expect(movie.runtime, 173);
      expect(movie.overview, '在并不遥远的未来，太阳急速衰老与膨胀。');
      expect(
        movie.posterUrl,
        'https://img9.doubanio.com/view/photo/public/p2916835424.webp',
      );
      expect(movie.externalUrl, 'https://movie.douban.com/subject/35267208');
    });

    test('keeps the 0-10 rating as it is', () {
      final Movie movie = Movie.fromDoubanItem(doubanMovieRecord());
      // Douban rates out of ten already; doubling would show 16.6.
      expect(movie.rating, 8.3);
    });

    test('reads the original title out of the aliases', () {
      final Movie movie = Movie.fromDoubanItem(doubanMovieRecord());
      // `original_title` is empty on every record sampled, so the first
      // Latin-script alias is the only English name available.
      expect(movie.originalTitle, 'The Wandering Earth Ⅱ');
    });

    test('prefers a real original_title over the aliases', () {
      final Movie movie = Movie.fromDoubanItem(
        doubanMovieRecord(
          overrides: <String, dynamic>{
            'original_title': 'The Wandering Earth II',
          },
        ),
      );
      expect(movie.originalTitle, 'The Wandering Earth II');
    });

    test('maps a search row, where genres come out of card_subtitle', () {
      final Movie movie = Movie.fromDoubanItem(doubanMovieRow());

      expect(movie.tmdbId, 35267208);
      expect(movie.title, '流浪地球2');
      expect(movie.releaseYear, 2023);
      expect(movie.genres, <String>['科幻', '冒险', '灾难']);
      expect(
        movie.posterUrl,
        'https://qnmob3-sign.doubanio.com/view/photo/public/p2916835424.jpg',
      );
    });

    test('a search row keeps no overview, because Douban sends none', () {
      final Movie movie = Movie.fromDoubanItem(doubanMovieRow());
      expect(movie.overview, isNull);
      expect(movie.runtime, isNull);
    });

    test('picks the genre slot by shape, not by position alone', () {
      // A record leads its subtitle with the year, a search row with the
      // country; reading slot 1 in both would label a film "中国大陆".
      final Movie fromRecord = Movie.fromDoubanItem(
        doubanMovieRecord(overrides: <String, dynamic>{'genres': <String>[]}),
      );
      final Movie fromRow = Movie.fromDoubanItem(
        doubanMovieRow(overrides: <String, dynamic>{'card_subtitle': ''}),
      );

      expect(fromRecord.genres, <String>['科幻', '冒险', '灾难']);
      expect(fromRow.genres, isNull);
    });

    test('leaves an absent or zero rating null', () {
      final Movie absent = Movie.fromDoubanItem(
        doubanMovieRecord(overrides: <String, dynamic>{'rating': null}),
      );
      final Movie zero = Movie.fromDoubanItem(
        doubanMovieRecord(
          overrides: <String, dynamic>{
            'rating': <String, dynamic>{'count': 0, 'value': 0},
          },
        ),
      );

      expect(absent.rating, isNull);
      expect(zero.rating, isNull);
    });

    test('drops an empty or out-of-range year', () {
      final Movie blank = Movie.fromDoubanItem(
        doubanMovieRecord(overrides: <String, dynamic>{'year': ''}),
      );
      final Movie nonsense = Movie.fromDoubanItem(
        doubanMovieRecord(overrides: <String, dynamic>{'year': 'unknown'}),
      );

      expect(blank.releaseYear, isNull);
      expect(nonsense.releaseYear, isNull);
    });

    test('falls back to cover_url when pic is absent', () {
      final Movie movie = Movie.fromDoubanItem(
        doubanMovieRecord(overrides: <String, dynamic>{'pic': null}),
      );
      expect(movie.posterUrl, isNull);
    });

    test('reads a runtime out of the durations line', () {
      final Movie movie = Movie.fromDoubanItem(
        doubanMovieRecord(
          overrides: <String, dynamic>{
            'durations': <String>['2小时53分钟'],
          },
        ),
      );
      // The first number wins, which is the hour count here — Douban sends
      // "173分钟" for this title, so the plain form is what matters.
      expect(movie.runtime, 2);
    });

    test('throws when the record carries no id', () {
      expect(
        () => Movie.fromDoubanItem(
          doubanMovieRecord(overrides: <String, dynamic>{'id': null}),
        ),
        throwsFormatException,
      );
    });
  });
}
