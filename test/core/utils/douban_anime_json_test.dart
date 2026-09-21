import 'package:core/models/anime.dart';
import 'package:core/models/data_source.dart';
import 'package:core/utils/douban_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// Douban has no animation subject type, so the two shapes have to be told
/// apart by hand: a search row's `target` is thin — no `intro`, no
/// `episodes_count`, and genres only inside `card_subtitle` — while
/// `/api/v2/tv/{id}` answers with the full 73-field record.
void main() {
  group('doubanIsAnimation', () {
    test('reads the genre list out of a search row', () {
      final Map<String, dynamic> row = <String, dynamic>{
        'card_subtitle': '日本 / 动画 音乐 / 斋藤圭一郎 / 青山吉能 铃代纱弓',
      };

      expect(doubanIsAnimation(row), isTrue);
    });

    test('a live-action row is not an animation', () {
      final Map<String, dynamic> row = <String, dynamic>{
        'card_subtitle': '中国大陆 / 剧情 历史 / 张艺谋 / 巩俐',
      };

      expect(doubanIsAnimation(row), isFalse);
    });

    test('a full record uses its own genre array', () {
      expect(
        doubanIsAnimation(<String, dynamic>{
          'genres': <String>['动作', '动画', '奇幻'],
        }),
        isTrue,
      );
      expect(
        doubanIsAnimation(<String, dynamic>{
          'genres': <String>['剧情', '历史'],
        }),
        isFalse,
      );
    });
  });

  group('doubanSubjectKind', () {
    test('prefers the type a full record states', () {
      expect(doubanSubjectKind(<String, dynamic>{'type': 'tv'}), 'tv');
      expect(doubanSubjectKind(<String, dynamic>{'subtype': 'movie'}), 'movie');
    });

    test('falls back to the uri a search row carries', () {
      expect(
        doubanSubjectKind(<String, dynamic>{
          'uri': 'douban://douban.com/tv/35366293',
        }),
        'tv',
      );
      expect(
        doubanSubjectKind(<String, dynamic>{
          'uri': 'douban://douban.com/movie/1291561',
        }),
        'movie',
      );
    });

    test('answers null when neither shape says', () {
      expect(doubanSubjectKind(<String, dynamic>{}), isNull);
    });
  });

  group('Anime.fromDouban', () {
    test('maps a search row, scaling the 0–10 score to 0–100', () {
      final Anime anime = Anime.fromDouban(<String, dynamic>{
        'id': '35366293',
        'title': '孤独摇滚！',
        'card_subtitle': '日本 / 动画 音乐 / 斋藤圭一郎 / 青山吉能 铃代纱弓',
        'cover_url': 'https://img.example/p2880400525.jpg',
        'rating': <String, dynamic>{'count': 76467, 'max': 10, 'value': 9.0},
        'uri': 'douban://douban.com/tv/35366293',
        'year': '2022',
      });

      expect(anime.id, 35366293);
      expect(anime.source, DataSource.douban);
      expect(anime.title, '孤独摇滚！');
      expect(anime.averageScore, 90);
      expect(anime.popularity, 76467);
      expect(anime.startYear, 2022);
      expect(anime.format, 'TV');
      expect(anime.genres, <String>['动画', '音乐']);
      expect(anime.coverUrl, 'https://img.example/p2880400525.jpg');
      expect(anime.externalUrl, 'https://movie.douban.com/subject/35366293');
      // A search row carries neither, so the detail call has to fill them in.
      expect(anime.description, isNull);
      expect(anime.episodes, isNull);
    });

    test('maps a full record, taking episodes and the Chinese synopsis', () {
      final Anime anime = Anime.fromDouban(<String, dynamic>{
        'id': '36714178',
        'title': '咒术回战 第三季',
        'type': 'tv',
        'year': '2026',
        'genres': <String>['动作', '动画', '奇幻'],
        'episodes_count': 12,
        'rating': <String, dynamic>{'count': 29632, 'max': 10, 'value': 8.8},
        'intro': '在惨烈的“涩谷事变”结束后，东京沦为咒灵横行的废墟。',
        'original_title': '呪術廻戦 死滅回遊 前編',
        'aka': <String>['Jujutsu Kaisen', '咒术回战 死灭回游 前篇'],
      });

      expect(anime.id, 36714178);
      expect(anime.episodes, 12);
      expect(anime.averageScore, 88);
      expect(anime.format, 'TV');
      expect(anime.description, '在惨烈的“涩谷事变”结束后，东京沦为咒灵横行的废墟。');
      // An animation record does state `original_title`, and it states the
      // Japanese name — so it is a native title, never an English one.
      expect(anime.titleNative, '呪術廻戦 死滅回遊 前編');
      expect(anime.titleEnglish, 'Jujutsu Kaisen');
    });

    test('a record without `original_title` has no native title to guess at',
        () {
      final Anime anime = Anime.fromDouban(<String, dynamic>{
        'id': '35366293',
        'title': '孤独摇滚！',
        'aka': <String>['Bocchi the Rock!'],
      });

      expect(anime.titleNative, isNull);
      expect(anime.titleEnglish, 'Bocchi the Rock!');
    });

    test('an animated film is a MOVIE, not a TV series', () {
      final Anime anime = Anime.fromDouban(<String, dynamic>{
        'id': '1291561',
        'title': '千与千寻',
        'uri': 'douban://douban.com/movie/1291561',
        'durations': <String>['125分钟'],
      });

      expect(anime.format, 'MOVIE');
      expect(anime.duration, 125);
    });

    test('a record without a numeric id is a format failure, not a guess', () {
      expect(
        () => Anime.fromDouban(<String, dynamic>{'title': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
