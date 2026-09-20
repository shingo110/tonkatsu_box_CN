import 'package:core/models/data_source.dart';
import 'package:core/models/tv_show.dart';
import 'package:core/utils/stable_id.dart';
import 'package:test/test.dart';

Map<String, dynamic> item([
  Map<String, dynamic> overrides = const <String, dynamic>{},
]) {
  return <String, dynamic>{
    'uuid': '2yMJKWEPBoYGHeRF2qTiX5',
    'id': 'https://neodb.social/tv/season/2yMJKWEPBoYGHeRF2qTiX5',
    'url': '/tv/season/2yMJKWEPBoYGHeRF2qTiX5',
    'api_url': '/api/tv/season/2yMJKWEPBoYGHeRF2qTiX5',
    'category': 'tv',
    'type': 'TVSeason',
    'parent_uuid': '5E6ybLCwnSLvDCSo8AYiaU',
    'display_title': 'Empresses in the Palace (The Legend of Zhen Huan)',
    'title': 'Empresses in the Palace (The Legend of Zhen Huan)',
    'orig_title': '',
    'localized_title': <Map<String, dynamic>>[
      <String, dynamic>{'lang': 'zh-cn', 'text': '甄嬛传 第 1 季'},
      <String, dynamic>{'lang': 'zh-cn', 'text': '甄嬛传'},
    ],
    'localized_description': <Map<String, dynamic>>[
      <String, dynamic>{'lang': 'zh-cn', 'text': '时为满清雍正元年，一场盛大的选秀拉开帷幕。'},
    ],
    'description': 'Zhen Huan, a 17-year-old innocent.',
    'cover_image_url': 'https://neodb.social/m/item/tvseason/cover.jpg',
    'rating': 8.8,
    'rating_count': 348,
    'tags': <String>['2011', '中国', '古装'],
    'genre': <String>['drama'],
    'year': 2011,
    'season_number': 1,
    'episode_count': 76,
    'episode_uuids': <String>[],
    'imdb': 'tt2374683',
    ...overrides,
  };
}

void main() {
  group('TvShow.fromNeoDBItem', () {
    test('stamps NeoDB as the source', () {
      expect(TvShow.fromNeoDBItem(item()).source, DataSource.neodb);
    });

    test('folds the season uuid into the integer id', () {
      final TvShow show = TvShow.fromNeoDBItem(item());

      expect(show.tmdbId, fnv1a64('2yMJKWEPBoYGHeRF2qTiX5'));
    });

    test('keeps the season number the localized title carries', () {
      // Search answers with TVSeason records, so the season belongs in the
      // title — a bare "甄嬛传" could not be told apart from season two.
      expect(TvShow.fromNeoDBItem(item()).title, '甄嬛传 第 1 季');
    });

    test('leaves the original title null on an empty orig_title', () {
      expect(TvShow.fromNeoDBItem(item()).originalTitle, isNull);
    });

    test('reads the rating on NeoDB\'s own 1-10 scale, undoubled', () {
      expect(TvShow.fromNeoDBItem(item()).rating, 8.8);
    });

    test('takes the episode count from the season record', () {
      expect(TvShow.fromNeoDBItem(item()).totalEpisodes, 76);
    });

    test('leaves the season total unknown on a season record', () {
      // A season carries no season count, and the show endpoint that has it
      // would cost one extra request per search row.
      expect(TvShow.fromNeoDBItem(item()).totalSeasons, isNull);
    });

    test('falls back to the tags year when the row carries no year', () {
      final TvShow show = TvShow.fromNeoDBItem(item(<String, dynamic>{
        'year': null,
      }));

      expect(show.firstAirYear, 2011);
    });

    test('takes the Chinese synopsis from the localized array', () {
      expect(
        TvShow.fromNeoDBItem(item()).overview,
        '时为满清雍正元年，一场盛大的选秀拉开帷幕。',
      );
    });

    test('links back to the NeoDB season page', () {
      expect(
        TvShow.fromNeoDBItem(item()).externalUrl,
        'https://neodb.social/tv/season/2yMJKWEPBoYGHeRF2qTiX5',
      );
    });

    test('leaves status null — NeoDB records no airing state', () {
      expect(TvShow.fromNeoDBItem(item()).status, isNull);
    });

    test('keeps the model usable when optional fields are missing', () {
      final TvShow show = TvShow.fromNeoDBItem(<String, dynamic>{
        'uuid': 'xyz',
        'title': 'Untitled',
      });

      expect(show.title, 'Untitled');
      expect(show.tmdbId, fnv1a64('xyz'));
      expect(show.totalEpisodes, isNull);
      expect(show.firstAirYear, isNull);
    });
  });
}
