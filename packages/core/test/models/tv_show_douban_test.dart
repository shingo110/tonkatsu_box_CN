import 'package:core/models/data_source.dart';
import 'package:core/models/tv_show.dart';
import 'package:test/test.dart';

/// A full `/api/v2/tv/{id}` record. `first_air_time` is present in the field
/// list the host documents but came back null on every series sampled, which
/// is why the year is read from `year`.
Map<String, dynamic> doubanTvRecord({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  final Map<String, dynamic> json = <String, dynamic>{
    'id': '35465232',
    'title': '狂飙',
    'original_title': '',
    'year': '2023',
    'genres': <String>['剧情', '犯罪'],
    'countries': <String>['中国大陆'],
    'durations': <String>[],
    'episodes_count': 39,
    'aka': <String>['Punch Out', 'The Knockout'],
    'rating': <String, dynamic>{
      'count': 1069465,
      'max': 10,
      'star_count': 4.5,
      'value': 8.5,
    },
    'pic': <String, dynamic>{
      'large': 'https://img2.doubanio.com/view/photo/public/p2886376181.webp',
    },
    'intro': '京海市一线刑警安欣，在与黑恶势力的斗争中不断遭到打击。',
    'is_tv': true,
    'subtype': 'tv',
    'type': 'tv',
    'uri': 'douban://douban.com/tv/35465232',
    'card_subtitle': '2023 / 中国大陆 / 剧情 犯罪 / 徐纪周 / 张译 张颂文',
  };
  json.addAll(overrides);
  return json;
}

/// The `target` object of one `/api/v2/search/movie?q=狂飙` row. The endpoint
/// mixes films and series, so `target_type` is what marks this one a series.
Map<String, dynamic> doubanTvRow({
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  final Map<String, dynamic> json = <String, dynamic>{
    'abstract': '',
    'card_subtitle': '中国大陆 / 剧情 犯罪 / 徐纪周 / 张译 张颂文',
    'cover_url':
        'https://qnmob3-sign.doubanio.com/view/photo/public/p2886376181.jpg',
    'has_linewatch': true,
    'id': '35465232',
    'rating': <String, dynamic>{
      'count': 1069464,
      'max': 10,
      'star_count': 4.5,
      'value': 8.5,
    },
    'title': '狂飙',
    'uri': 'douban://douban.com/tv/35465232',
    'year': '2023',
  };
  json.addAll(overrides);
  return json;
}

void main() {
  group('TvShow.fromDoubanItem', () {
    test('maps a full series record', () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRecord());

      expect(show.tmdbId, 35465232);
      expect(show.title, '狂飙');
      expect(show.source, DataSource.douban);
      expect(show.firstAirYear, 2023);
      expect(show.totalEpisodes, 39);
      expect(show.genres, <String>['剧情', '犯罪']);
      expect(show.overview, '京海市一线刑警安欣，在与黑恶势力的斗争中不断遭到打击。');
      expect(show.externalUrl, 'https://movie.douban.com/subject/35465232');
    });

    test('keeps the 0-10 rating as it is', () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRecord());
      // Douban rates out of ten already; doubling would show 17.0.
      expect(show.rating, 8.5);
    });

    test('reads the original title out of the aliases', () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRecord());
      expect(show.originalTitle, 'Punch Out');
    });

    test('maps a search row', () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRow());

      expect(show.tmdbId, 35465232);
      expect(show.title, '狂飙');
      expect(show.firstAirYear, 2023);
      expect(show.genres, <String>['剧情', '犯罪']);
    });

    test('a search row has no episode count, because Douban sends none', () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRow());
      expect(show.totalEpisodes, isNull);
      expect(show.overview, isNull);
    });

    test('leaves the season count alone — Douban files one subject per show',
        () {
      final TvShow show = TvShow.fromDoubanItem(doubanTvRecord());
      expect(show.totalSeasons, isNull);
      expect(show.status, isNull);
    });

    test('drops a zero episode count rather than reporting none', () {
      final TvShow show = TvShow.fromDoubanItem(
        doubanTvRecord(overrides: <String, dynamic>{'episodes_count': 0}),
      );
      expect(show.totalEpisodes, isNull);
    });

    test('throws when the record carries no id', () {
      expect(
        () => TvShow.fromDoubanItem(
          doubanTvRecord(overrides: <String, dynamic>{'id': null}),
        ),
        throwsFormatException,
      );
    });
  });
}
