import 'package:core/models/data_source.dart';
import 'package:core/models/manga.dart';
import 'package:test/test.dart';

/// Payloads are trimmed copies of the archived response from
/// `probe/bangumi_manga_meta.json` (a `type: [1]` + `meta_tags: [漫画]` search),
/// so the field names and their shapes are the live ones.
Map<String, dynamic> _subject() => <String, dynamic>{
      'id': 3510,
      'name': 'ONE PIECE',
      'name_cn': '航海王',
      'date': '1997-12-24',
      'platform': '漫画',
      'summary': '　　拥有财富、名声、权力，这世界上的一切的男人"海贼王"哥尔·D·罗杰。',
      'image': 'https://lain.bgm.tv/pic/cover/l/15/e1/3510_pWiY9.jpg',
      'images': <String, dynamic>{
        'large': 'https://lain.bgm.tv/pic/cover/l/15/e1/3510_pWiY9.jpg',
        'common': 'https://lain.bgm.tv/r/400/pic/cover/l/15/e1/3510_pWiY9.jpg',
      },
      'eps': 180,
      'volumes': 13,
      'meta_tags': <dynamic>['日本', '漫画', '战斗', '少年', '连载中'],
      'rating': <String, dynamic>{
        'rank': 32,
        'score': 8.8,
        'total': 2667,
      },
      'tags': <dynamic>[
        <String, dynamic>{'name': '海贼王', 'count': 634},
        <String, dynamic>{'name': '尾田荣一郎', 'count': 493},
        <String, dynamic>{'name': 'JUMP', 'count': 446},
      ],
      'infobox': <dynamic>[
        <String, dynamic>{'key': '中文名', 'value': '航海王'},
        <String, dynamic>{'key': '作者', 'value': '尾田栄一郎'},
        <String, dynamic>{'key': '出版社', 'value': '集英社'},
      ],
    };

void main() {
  group('Manga.fromBangumi', () {
    test('prefers the Chinese title and keeps the original', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.title, '航海王');
      expect(manga.titleNative, 'ONE PIECE');
      expect(manga.source, DataSource.bangumi);
      expect(manga.id, 3510);
    });

    test('falls back to the original title when there is no Chinese one', () {
      final Map<String, dynamic> json = _subject()..['name_cn'] = '';

      expect(Manga.fromBangumi(json).title, 'ONE PIECE');
    });

    test('scales the community score from 0-10 to 0-100', () {
      expect(Manga.fromBangumi(_subject()).averageScore, 88);
    });

    test('leaves the score null when the record carries none', () {
      final Map<String, dynamic> json = _subject()..['rating'] = null;
      expect(Manga.fromBangumi(json).averageScore, isNull);

      final Map<String, dynamic> zero = _subject()
        ..['rating'] = <String, dynamic>{'score': 0};
      expect(Manga.fromBangumi(zero).averageScore, isNull);
    });

    test('reads the cover at both sizes', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.coverUrl, 'https://lain.bgm.tv/pic/cover/l/15/e1/3510_pWiY9.jpg');
      expect(manga.coverUrlMedium,
          'https://lain.bgm.tv/r/400/pic/cover/l/15/e1/3510_pWiY9.jpg');
    });

    test('reads chapters and volumes, mapping Bangumi 0 to unknown', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.chapters, 180);
      expect(manga.volumes, 13);
    });

    test('treats a zero count as unknown rather than a real zero', () {
      // 连载中 works ship 0 for both until someone counts them.
      final Map<String, dynamic> json = _subject()
        ..['eps'] = 0
        ..['volumes'] = 0;
      final Manga manga = Manga.fromBangumi(json);

      expect(manga.chapters, isNull);
      expect(manga.volumes, isNull);
    });

    test('splits the start date into year, month and day', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.startYear, 1997);
      expect(manga.startMonth, 12);
      expect(manga.startDay, 24);
    });

    test('leaves the trailing date parts null on a partial date', () {
      final Map<String, dynamic> json = _subject()..['date'] = '2024-04';
      final Manga manga = Manga.fromBangumi(json);

      expect(manga.startYear, 2024);
      expect(manga.startMonth, 4);
      expect(manga.startDay, isNull);
    });

    test('maps the serialisation meta tag onto the status vocabulary', () {
      expect(Manga.fromBangumi(_subject()).status, 'RELEASING');

      final Map<String, dynamic> finished = _subject()
        ..['meta_tags'] = <dynamic>['日本', '漫画', '已完结'];
      expect(Manga.fromBangumi(finished).status, 'FINISHED');
    });

    test('leaves the status null when no meta tag states one', () {
      final Map<String, dynamic> json = _subject()
        ..['meta_tags'] = <dynamic>['日本', '漫画'];
      expect(Manga.fromBangumi(json).status, isNull);
    });

    test('a future date wins over the serialisation tag', () {
      final Map<String, dynamic> json = _subject()
        ..['date'] = '2099-01-01'
        ..['meta_tags'] = <dynamic>['漫画', '连载中'];
      expect(Manga.fromBangumi(json).status, 'NOT_YET_RELEASED');
    });

    test('reads the format from the medium and the authors from the infobox',
        () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.format, 'MANGA');
      expect(manga.authors, <String>['尾田栄一郎']);
    });

    test('leaves the format null when the platform is not a comic', () {
      final Map<String, dynamic> json = _subject()..['platform'] = '小说';
      expect(Manga.fromBangumi(json).format, isNull);
    });

    test('reads the community tags and caps them', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.tags, <String>['海贼王', '尾田荣一郎', 'JUMP']);
    });

    test('drops the tag name when a row carries none', () {
      final Map<String, dynamic> json = _subject()
        ..['tags'] = <dynamic>[
          <String, dynamic>{'count': 3},
          <String, dynamic>{'name': 'JUMP', 'count': 446},
        ];
      expect(Manga.fromBangumi(json).tags, <String>['JUMP']);
    });

    test('answers null tags for an empty list', () {
      final Map<String, dynamic> json = _subject()..['tags'] = <dynamic>[];
      expect(Manga.fromBangumi(json).tags, isNull);
    });

    test('reads the synopsis and the public page', () {
      final Manga manga = Manga.fromBangumi(_subject());

      expect(manga.description, contains('哥尔·D·罗杰'));
      expect(manga.externalUrl, 'https://bgm.tv/subject/3510');
    });

    test('survives a minimal payload', () {
      final Manga manga = Manga.fromBangumi(<String, dynamic>{
        'id': 42,
        'name': 'Solo Leveling',
      });

      expect(manga.id, 42);
      expect(manga.title, 'Solo Leveling');
      expect(manga.titleNative, 'Solo Leveling');
      expect(manga.authors, isNull);
      expect(manga.chapters, isNull);
      expect(manga.status, isNull);
    });

    test('rejects a record without a usable id', () {
      expect(
        () => Manga.fromBangumi(<String, dynamic>{'name': 'X'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
