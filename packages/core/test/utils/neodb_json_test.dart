import 'package:core/utils/neodb_json.dart';
import 'package:test/test.dart';

void main() {
  group('neodbChineseText', () {
    test('ranks zh-cn above every other Chinese tag', () {
      final String? text = neodbChineseText(<Map<String, dynamic>>[
        <String, dynamic>{'lang': 'zh-tw', 'text': '霸王別姬'},
        <String, dynamic>{'lang': 'zh-cn', 'text': '霸王别姬'},
      ]);

      expect(text, '霸王别姬');
    });

    test('falls back through zh-hans and a bare zh', () {
      expect(
        neodbChineseText(<Map<String, dynamic>>[
          <String, dynamic>{'lang': 'en', 'text': 'Farewell My Concubine'},
          <String, dynamic>{'lang': 'zh-hans', 'text': '霸王别姬'},
        ]),
        '霸王别姬',
      );
      expect(
        neodbChineseText(<Map<String, dynamic>>[
          <String, dynamic>{'lang': 'zh', 'text': '甄嬛传'},
        ]),
        '甄嬛传',
      );
    });

    test('ignores English-only renderings and non-list payloads', () {
      expect(
        neodbChineseText(<Map<String, dynamic>>[
          <String, dynamic>{'lang': 'en', 'text': 'Farewell My Concubine'},
        ]),
        isNull,
      );
      expect(neodbChineseText('not a list'), isNull);
      expect(neodbChineseText(null), isNull);
    });
  });

  group('neodbItemTitle', () {
    test('prefers the Chinese rendering over the English display_title', () {
      expect(
        neodbItemTitle(<String, dynamic>{
          'display_title': 'Farewell My Concubine',
          'title': 'Farewell My Concubine',
          'localized_title': <Map<String, dynamic>>[
            <String, dynamic>{'lang': 'zh-cn', 'text': '霸王别姬'},
          ],
        }),
        '霸王别姬',
      );
    });

    test('falls back to display_title and then to title', () {
      expect(
        neodbItemTitle(<String, dynamic>{'display_title': 'Untitled'}),
        'Untitled',
      );
      expect(
        neodbItemTitle(<String, dynamic>{'title': 'Fallback'}),
        'Fallback',
      );
      expect(neodbItemTitle(<String, dynamic>{}), isNull);
    });

    test('treats a blank string as absent', () {
      expect(
        neodbItemTitle(<String, dynamic>{'display_title': '   ', 'title': ''}),
        isNull,
      );
    });
  });

  group('neodbItemOriginalTitle', () {
    test('drops an original title identical to the localized one', () {
      expect(
        neodbItemOriginalTitle(<String, dynamic>{'orig_title': '霸王别姬'}, '霸王别姬'),
        isNull,
      );
    });

    test('keeps a genuinely different original title', () {
      expect(
        neodbItemOriginalTitle(
          <String, dynamic>{'orig_title': 'Ba wang bie ji'},
          '霸王别姬',
        ),
        'Ba wang bie ji',
      );
    });

    test('treats the empty orig_title of imported records as absent', () {
      expect(
        neodbItemOriginalTitle(<String, dynamic>{'orig_title': ''}, '甄嬛传'),
        isNull,
      );
    });
  });

  group('neodbItemYear', () {
    test('prefers the year field the detail response carries', () {
      expect(
        neodbItemYear(<String, dynamic>{'year': 1993, 'tags': <String>['2020s']}),
        1993,
      );
    });

    test('scans tags when the search row omits year', () {
      expect(
        neodbItemYear(<String, dynamic>{'tags': <String>['1990s', '1994']}),
        1994,
      );
    });

    test('does not mistake a decade bucket for a year', () {
      expect(
        neodbItemYear(<String, dynamic>{'tags': <String>['2020s', '中国']}),
        isNull,
      );
    });

    test('rejects a four-digit tag outside the plausible range', () {
      expect(
        neodbItemYear(<String, dynamic>{'tags': <String>['9999']}),
        isNull,
      );
    });

    test('ignores a year-shaped tag that is not four characters', () {
      expect(
        neodbItemYear(<String, dynamic>{'tags': <String>['2027未看', '2027']}),
        2027,
      );
    });
  });

  group('neodbRuntimeMinutes', () {
    test('converts the length in seconds to whole minutes', () {
      expect(neodbRuntimeMinutes(10260), 171);
    });

    test('rounds to the nearest minute', () {
      expect(neodbRuntimeMinutes(100), 2);
    });

    test('returns null for a zero, negative or absent length', () {
      expect(neodbRuntimeMinutes(0), isNull);
      expect(neodbRuntimeMinutes(-30), isNull);
      expect(neodbRuntimeMinutes(null), isNull);
      expect(neodbRuntimeMinutes('nonsense'), isNull);
    });
  });

  group('neodbItemRating', () {
    test('keeps the value on NeoDB\'s own 1-10 scale', () {
      expect(neodbItemRating(9.5), 9.5);
    });

    test('reads zero and absent as unrated', () {
      expect(neodbItemRating(0), isNull);
      expect(neodbItemRating(null), isNull);
    });
  });

  group('neodbItemGenres', () {
    test('keeps slugs verbatim, deduplicated and without blanks', () {
      expect(
        neodbItemGenres(<String>['drama', 'romance', 'drama', '  ']),
        <String>['drama', 'romance'],
      );
    });

    test('returns an empty list for a non-list payload', () {
      expect(neodbItemGenres(null), isEmpty);
    });
  });

  group('neodbItemUrl', () {
    test('prefers the absolute id', () {
      expect(
        neodbItemUrl(<String, dynamic>{
          'id': 'https://neodb.social/movie/abc',
          'url': '/movie/abc',
        }),
        'https://neodb.social/movie/abc',
      );
    });

    test('builds an absolute url from the relative form', () {
      expect(
        neodbItemUrl(<String, dynamic>{'url': '/movie/abc'}),
        'https://neodb.social/movie/abc',
      );
    });

    test('returns null when neither field is usable', () {
      expect(neodbItemUrl(<String, dynamic>{}), isNull);
    });
  });

  group('neodbUuidFromUrl', () {
    test('takes the last path segment of a movie page', () {
      expect(
        neodbUuidFromUrl('https://neodb.social/movie/4RQwAeTa5E2DKPPbFt4UVJ'),
        '4RQwAeTa5E2DKPPbFt4UVJ',
      );
    });

    test('handles the season path a TV record stores', () {
      expect(
        neodbUuidFromUrl(
          'https://neodb.social/tv/season/2yMJKWEPBoYGHeRF2qTiX5',
        ),
        '2yMJKWEPBoYGHeRF2qTiX5',
      );
    });

    test('refuses a foreign host so another provider cannot leak through', () {
      expect(
        neodbUuidFromUrl('https://www.themoviedb.org/movie/123'),
        isNull,
      );
    });

    test('returns null for null, blank or unparsable input', () {
      expect(neodbUuidFromUrl(null), isNull);
      expect(neodbUuidFromUrl(''), isNull);
      expect(neodbUuidFromUrl('not a url'), isNull);
      expect(neodbUuidFromUrl('https://neodb.social/'), isNull);
    });
  });
}
