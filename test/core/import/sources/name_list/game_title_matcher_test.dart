import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/import/sources/name_list/game_title_matcher.dart';

void main() {
  group('normalizeTitle', () {
    test('keeps Chinese characters instead of erasing them', () {
      // The reason this matcher exists at all: the RetroAchievements normalizer
      // keeps [a-z0-9] only and turns this into an empty string.
      expect(GameTitleMatcher.normalizeTitle('战神：诸神黄昏'), '战神诸神黄昏');
      expect(GameTitleMatcher.normalizeTitle('最后生还者 第二部'), '最后生还者第二部');
    });

    test('drops punctuation, spacing and case', () {
      expect(
        GameTitleMatcher.normalizeTitle("Sid Meier's Civ VI"),
        'sidmeierscivvi',
      );
      expect(GameTitleMatcher.normalizeTitle('God-of-War'), 'godofwar');
    });

    test('keeps kana and hangul', () {
      expect(GameTitleMatcher.normalizeTitle('ゼルダの伝説'), 'ゼルダの伝説');
      expect(GameTitleMatcher.normalizeTitle('젤다의 전설'), '젤다의전설');
    });

    test('returns empty for a title of pure punctuation', () {
      expect(GameTitleMatcher.normalizeTitle('!!!'), '');
    });
  });

  group('hasHan', () {
    test('detects Chinese titles', () {
      expect(GameTitleMatcher.hasHan('最后生还者'), isTrue);
      expect(GameTitleMatcher.hasHan('战神'), isTrue);
    });

    test('counts Japanese kanji as Han', () {
      // 伝 and 説 are Han characters, so a Japanese title containing kanji
      // routes to the same catalogue a Chinese title would.
      expect(GameTitleMatcher.hasHan('ゼルダの伝説'), isTrue);
    });

    test('is false for Latin and for pure kana', () {
      expect(GameTitleMatcher.hasHan('Ghost of Tsushima'), isFalse);
      expect(GameTitleMatcher.hasHan('ゼルダ'), isFalse);
    });
  });

  group('bigrams', () {
    test('empty string yields nothing', () {
      expect(GameTitleMatcher.bigrams(''), isEmpty);
    });

    test('single rune yields itself', () {
      expect(GameTitleMatcher.bigrams('战'), <String>{'战'});
    });

    test('two runes yield one gram', () {
      expect(GameTitleMatcher.bigrams('战神'), <String>{'战神'});
    });

    test('splits Latin runs by two', () {
      expect(GameTitleMatcher.bigrams('abc'), <String>{'ab', 'bc'});
    });
  });

  group('diceCoefficient', () {
    test('identical bags score 1', () {
      expect(
        GameTitleMatcher.diceCoefficient(
          <String>{'ab', 'bc'},
          <String>{'ab', 'bc'},
        ),
        1.0,
      );
    });

    test('disjoint bags score 0', () {
      expect(
        GameTitleMatcher.diceCoefficient(<String>{'ab'}, <String>{'cd'}),
        0.0,
      );
    });

    test('an empty bag scores 0', () {
      expect(GameTitleMatcher.diceCoefficient(<String>{}, <String>{'ab'}), 0.0);
    });
  });

  group('score', () {
    test('identical titles score 100 regardless of case', () {
      expect(GameTitleMatcher.score('God of War', 'God of War'), 100);
      expect(GameTitleMatcher.score('god of war', 'God of War'), 100);
    });

    test('punctuation-only differences score 95', () {
      expect(GameTitleMatcher.score('God-of-War', 'God of War'), 95);
      // Real pair: the store prints 地平线：西之绝境 for what users type with a
      // space.
      expect(GameTitleMatcher.score('地平线 西之绝境', '地平线：西之绝境'), 95);
    });

    test('an appended extension scores in the fair band', () {
      final int score =
          GameTitleMatcher.score('God of War', 'God of War Ragnarök');
      expect(score, greaterThanOrEqualTo(80));
      expect(score, lessThan(GameTitleMatcher.normalizedScore));
    });
  });

  group('score against real catalogue rows', () {
    // Every case below is a row the live Chinese catalogue actually returned
    // for a PlayStation title; see probe/ps5_name_match_probe.py.

    test('an appended subtitle is the same franchise', () {
      expect(
        GameTitleMatcher.score('最后生还者', '最后生还者 第二部'),
        greaterThanOrEqualTo(GameTitleMatcher.confidentScore),
      );
      expect(
        GameTitleMatcher.score('对马岛之魂', '对马岛之魂 导演剪辑版'),
        greaterThanOrEqualTo(GameTitleMatcher.confidentScore),
      );
      expect(
        GameTitleMatcher.score('漫威蜘蛛侠', '漫威蜘蛛侠 2'),
        greaterThanOrEqualTo(GameTitleMatcher.confidentScore),
      );
    });

    test('a word borrowed at the end of a longer title is not the game', () {
      // TapTap answers 血源诅咒 with 樱花女校：血源诅咒 — a different game that
      // happens to end in the same three characters.
      expect(
        GameTitleMatcher.score('血源诅咒', '樱花女校：血源诅咒'),
        GameTitleMatcher.nestedCeilingScore,
      );
      expect(
        GameTitleMatcher.bestIndex('血源诅咒', <String>['樱花女校：血源诅咒']),
        -1,
      );
    });

    test('a shared word is not the game', () {
      // TapTap answers 战神 with 烈火战神, 战神传说 and 战神遗迹 — all mobile
      // titles, none of them God of War.
      for (final String clone in <String>['烈火战神', '战神传说', '战神遗迹']) {
        expect(
          GameTitleMatcher.score('战神', clone),
          lessThan(GameTitleMatcher.confidentScore),
          reason: '$clone must not stand in for 战神',
        );
      }
      expect(
        GameTitleMatcher.bestIndex('战神', <String>['烈火战神', '战神传说']),
        -1,
      );
    });

    test('a bare two-character title does not claim its sequels', () {
      // 战神 alone must not be read as 战神：诸神黄昏.
      expect(
        GameTitleMatcher.score('战神', '战神：诸神黄昏'),
        lessThan(GameTitleMatcher.confidentScore),
      );
    });

    test('an exact row always wins over a heuristic one', () {
      // 双人成行 ranks third behind 两人成行 / 双人同行 in the live catalogue.
      expect(
        GameTitleMatcher.bestIndex(
          '双人成行',
          <String>['两人成行', '双人同行', '双人成行'],
        ),
        2,
      );
    });

    test('the fuller edition outranks a bare original', () {
      // 生化危机 4 (2005) precedes 生化危机 4：重制版 in the catalogue, but the
      // complete title is the better answer for the query as typed.
      expect(GameTitleMatcher.score('生化危机4', '生化危机 4：重制版'), greaterThan(80));
    });
  });

  group('confidence floor', () {
    test('unrelated titles score nothing', () {
      expect(GameTitleMatcher.score('God of War', 'Gran Turismo 7'), 0);
      expect(GameTitleMatcher.score('艾尔登法环', '死亡搁浅'), 0);
    });

    test('empty input scores nothing', () {
      expect(GameTitleMatcher.score('', 'God of War'), 0);
      expect(GameTitleMatcher.score('God of War', '   '), 0);
    });

    test('never exceeds the exact score, which only an identical title reaches',
        () {
      for (final String candidate in <String>[
        'God of War',
        'God of War Ragnarök',
        'God-of-War',
        'God of War (2018)',
      ]) {
        final int score = GameTitleMatcher.score('God of War', candidate);
        expect(score, lessThanOrEqualTo(GameTitleMatcher.exactScore));
        if (candidate != 'God of War') {
          expect(score, lessThanOrEqualTo(GameTitleMatcher.normalizedScore));
        }
      }
    });

    test('a Dice-only match can never be preselected', () {
      // The band is capped below the confident score by construction; this
      // pins the cap so a future tweak cannot silently let clones through.
      expect(
        GameTitleMatcher.diceFloorScore + GameTitleMatcher.diceSpanScore,
        lessThan(GameTitleMatcher.confidentScore),
      );
      expect(
        GameTitleMatcher.nestedCeilingScore,
        lessThan(GameTitleMatcher.confidentScore),
      );
    });
  });

  group('qualityOf', () {
    test('maps scores onto the preview bands', () {
      expect(GameTitleMatcher.qualityOf(100), MatchQuality.exact);
      expect(GameTitleMatcher.qualityOf(95), MatchQuality.strong);
      expect(GameTitleMatcher.qualityOf(84), MatchQuality.fair);
      expect(GameTitleMatcher.qualityOf(80), MatchQuality.fair);
      expect(GameTitleMatcher.qualityOf(79), MatchQuality.weak);
      expect(GameTitleMatcher.qualityOf(30), MatchQuality.weak);
      expect(GameTitleMatcher.qualityOf(29), MatchQuality.none);
      expect(GameTitleMatcher.qualityOf(0), MatchQuality.none);
    });
  });

  group('bestIndex', () {
    test('picks the exact match over an earlier near miss', () {
      expect(
        GameTitleMatcher.bestIndex('战神', <String>['战争之神', '战神']),
        1,
      );
    });

    test('refuses a candidate below the confidence floor', () {
      expect(GameTitleMatcher.bestIndex('战神', <String>['战争之神']), -1);
    });

    test('returns -1 for an empty candidate list', () {
      expect(GameTitleMatcher.bestIndex('战神', const <String>[]), -1);
    });
  });
}
