import 'package:core/models/anime.dart';
import 'package:core/models/data_source.dart';
import 'package:test/test.dart';

Map<String, dynamic> subject([Map<String, dynamic> overrides = const <String, dynamic>{}]) {
  return <String, dynamic>{
    'id': 55770,
    'name': '進撃の巨人',
    'name_cn': '进击的巨人',
    'date': '2013-04-06',
    'platform': 'TV',
    'eps': 25,
    'rating': <String, dynamic>{'score': 8.2, 'rank': 118},
    'summary': '人类的自由。',
    'images': <String, dynamic>{
      'large': 'https://lain.bgm.tv/large.jpg',
      'common': 'https://lain.bgm.tv/common.jpg',
    },
    'tags': <Map<String, dynamic>>[
      <String, dynamic>{'name': '热血', 'count': 5936},
      <String, dynamic>{'name': '漫画改', 'count': 3381},
    ],
    'infobox': <Map<String, dynamic>>[
      <String, dynamic>{'key': '中文名', 'value': '进击的巨人'},
      <String, dynamic>{'key': '动画制作', 'value': 'WIT STUDIO'},
    ],
    ...overrides,
  };
}

void main() {
  group('Anime.fromBangumi', () {
    group('titles', () {
      test('puts the Chinese title in the default slot and keeps the original',
          () {
        final Anime anime = Anime.fromBangumi(subject());

        expect(anime.title, '进击的巨人');
        expect(anime.titleNative, '進撃の巨人');
        expect(anime.source, DataSource.bangumi);
      });

      test('falls back to the original title when there is no Chinese one', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'name_cn': null}));

        expect(anime.title, '進撃の巨人');
        expect(anime.titleNative, '進撃の巨人');
      });

      test('reads an empty Chinese title as absent', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'name_cn': ''}));

        expect(anime.title, '進撃の巨人');
      });

      test('falls back to Unknown when neither title is present', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'name': null, 'name_cn': null}),
        );

        expect(anime.title, 'Unknown');
        expect(anime.titleNative, isNull);
      });
    });

    group('rating', () {
      test('scales the 0-10 score onto the 0-100 field', () {
        expect(Anime.fromBangumi(subject()).averageScore, 82);
      });

      test('rounds a fractional score', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{
            'rating': <String, dynamic>{'score': 7.25},
          }),
        );

        expect(anime.averageScore, 73);
      });

      test('is null when the subject has no rating block', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'rating': null}));

        expect(anime.averageScore, isNull);
      });

      test('is null when the rating block carries no score', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{
            'rating': <String, dynamic>{'total': 0},
          }),
        );

        expect(anime.averageScore, isNull);
      });
    });

    group('covers', () {
      test('reads the large and common variants', () {
        final Anime anime = Anime.fromBangumi(subject());

        expect(anime.coverUrl, 'https://lain.bgm.tv/large.jpg');
        expect(anime.coverUrlMedium, 'https://lain.bgm.tv/common.jpg');
      });

      test('falls back to the flat image field when images is absent', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{
            'images': null,
            'image': 'https://lain.bgm.tv/flat.jpg',
          }),
        );

        expect(anime.coverUrl, 'https://lain.bgm.tv/flat.jpg');
        expect(anime.coverUrlMedium, isNull);
      });
    });

    group('dates', () {
      test('splits a full YYYY-MM-DD date', () {
        final Anime anime = Anime.fromBangumi(subject());

        expect(anime.startYear, 2013);
        expect(anime.startMonth, 4);
        expect(anime.startDay, 6);
      });

      test('reads a calendar row through air_date', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'date': null, 'air_date': '2026-07-06'}),
        );

        expect(anime.startYear, 2026);
        expect(anime.startMonth, 7);
        expect(anime.startDay, 6);
      });

      test('leaves the trailing parts null on a partial date', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'date': '2024-04'}));

        expect(anime.startYear, 2024);
        expect(anime.startMonth, 4);
        expect(anime.startDay, isNull);
      });

      test('leaves every part null without a date', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'date': null, 'air_date': null}),
        );

        expect(anime.startYear, isNull);
        expect(anime.startMonth, isNull);
        expect(anime.startDay, isNull);
      });
    });

    group('status', () {
      test('marks a future start date as not yet released', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'date': '2999-01-01'}),
        );

        expect(anime.status, 'NOT_YET_RELEASED');
      });

      test('leaves a past start date unknown — Bangumi has no airing flag', () {
        expect(Anime.fromBangumi(subject()).status, isNull);
      });

      test('is null without a date', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'date': null, 'air_date': null}),
        );

        expect(anime.status, isNull);
      });
    });

    group('format', () {
      for (final (String platform, String expected) in <(String, String)>[
        ('TV', 'TV'),
        ('WEB', 'ONA'),
        ('OVA', 'OVA'),
        ('OAD', 'OVA'),
        ('剧场版', 'MOVIE'),
      ]) {
        test('maps $platform to $expected', () {
          final Anime anime = Anime.fromBangumi(
            subject(<String, dynamic>{'platform': platform}),
          );

          expect(anime.format, expected);
        });
      }

      test('leaves an unknown platform null', () {
        final Anime anime = Anime.fromBangumi(
          subject(<String, dynamic>{'platform': '小说'}),
        );

        expect(anime.format, isNull);
      });
    });

    group('tags', () {
      test('keeps the community order and drops the vote counts', () {
        expect(Anime.fromBangumi(subject()).tags, <String>['热血', '漫画改']);
      });

      test('caps the list — the tail is one-off spelling variants', () {
        final List<Map<String, dynamic>> many = <Map<String, dynamic>>[
          for (int i = 0; i < 20; i++)
            <String, dynamic>{'name': 'tag$i', 'count': 100 - i},
        ];
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'tags': many}));

        expect(anime.tags, hasLength(12));
        expect(anime.tags!.last, 'tag11');
      });

      test('is null without a tag list', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'tags': null}));

        expect(anime.tags, isNull);
      });
    });

    group('studios', () {
      test('prefers the dedicated studio key', () {
        expect(Anime.fromBangumi(subject()).studios, <String>['WIT STUDIO']);
      });

      test('falls back to the production committee', () {
        final Anime anime = Anime.fromBangumi(subject(<String, dynamic>{
          'infobox': <Map<String, dynamic>>[
            <String, dynamic>{'key': '製作', 'value': 'Production I.G'},
          ],
        }));

        expect(anime.studios, <String>['Production I.G']);
      });

      test('splits a compound value and drops duplicates', () {
        final Anime anime = Anime.fromBangumi(subject(<String, dynamic>{
          'infobox': <Map<String, dynamic>>[
            <String, dynamic>{
              'key': '动画制作',
              'value': 'Bones / Bones / MAPPA',
            },
          ],
        }));

        expect(anime.studios, <String>['Bones', 'MAPPA']);
      });

      test('reads the list-of-variant infobox shape', () {
        final Anime anime = Anime.fromBangumi(subject(<String, dynamic>{
          'infobox': <Map<String, dynamic>>[
            <String, dynamic>{
              'key': '动画制作',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{'v': '京都アニメーション'},
              ],
            },
          ],
        }));

        expect(anime.studios, <String>['京都アニメーション']);
      });

      test('is null without an infobox', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'infobox': null}));

        expect(anime.studios, isNull);
      });
    });

    group('remaining fields', () {
      test('reads the episode count, description and external url', () {
        final Anime anime = Anime.fromBangumi(subject());

        expect(anime.episodes, 25);
        expect(anime.description, '人类的自由。');
        expect(anime.externalUrl, 'https://bgm.tv/subject/55770');
      });

      test('reads an empty summary as absent', () {
        final Anime anime =
            Anime.fromBangumi(subject(<String, dynamic>{'summary': ''}));

        expect(anime.description, isNull);
      });

      test('has no banner and no next-airing data', () {
        final Anime anime = Anime.fromBangumi(subject());

        expect(anime.bannerUrl, isNull);
        expect(anime.nextAiringEpisode, isNull);
        expect(anime.nextAiringAt, isNull);
      });
    });

    test('survives a minimal payload', () {
      final Anime anime = Anime.fromBangumi(<String, dynamic>{'id': 1});

      expect(anime.id, 1);
      expect(anime.title, 'Unknown');
      expect(anime.source, DataSource.bangumi);
      expect(anime.episodes, isNull);
      expect(anime.averageScore, isNull);
      expect(anime.tags, isNull);
      expect(anime.description, isNull);
    });
  });
}
