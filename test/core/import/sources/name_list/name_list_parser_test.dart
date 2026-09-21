import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/import/sources/name_list/name_list_parser.dart';

void main() {
  group('parse', () {
    test('strips list markers from every line', () {
      expect(
        NameListParser.parse('1. God of War\n2. 战神\n\n- 血源诅咒'),
        <String>['God of War', '战神', '血源诅咒'],
      );
    });

    test('keeps Chinese titles intact', () {
      expect(
        NameListParser.parse('对马岛之魂 导演剪辑版'),
        <String>['对马岛之魂 导演剪辑版'],
      );
    });

    test('drops a trailing platform tag in brackets', () {
      expect(NameListParser.parse('最后生还者 (PS5)'), <String>['最后生还者']);
    });

    test('drops a trailing platform tag after a dash', () {
      expect(
        NameListParser.parse('Ghost of Tsushima - PS4'),
        <String>['Ghost of Tsushima'],
      );
    });

    test('drops a line that is nothing but a platform tag', () {
      expect(
        NameListParser.parse('PS5\nGod of War\n(PS4)'),
        <String>['God of War'],
      );
    });

    test('keeps a title that merely contains a platform name', () {
      expect(NameListParser.parse('PS5 Simulator'), <String>['PS5 Simulator']);
    });

    test('de-duplicates on normalization, keeping the first spelling', () {
      expect(
        NameListParser.parse('God of War\ngod of war\nGod-of-War'),
        <String>['God of War'],
      );
    });

    test('de-duplicates Chinese titles across bracket styles', () {
      expect(
        NameListParser.parse('战神：诸神黄昏\n战神 诸神黄昏'),
        <String>['战神：诸神黄昏'],
      );
    });

    test('drops numbers, comments and stray glyphs', () {
      expect(
        NameListParser.parse('123\n# note\n!!!\nA Way Out'),
        <String>['A Way Out'],
      );
    });

    test('unwraps quoted titles', () {
      expect(NameListParser.parse('"Elden Ring"'), <String>['Elden Ring']);
    });

    test('tolerates CRLF line endings', () {
      expect(
        NameListParser.parse('A Way Out\r\nIt Takes Two'),
        <String>['A Way Out', 'It Takes Two'],
      );
    });

    test('strips a byte order mark', () {
      expect(NameListParser.parse('\uFEFFElden Ring'), <String>['Elden Ring']);
    });

    test('drops an over-long line', () {
      final String paragraph = 'x' * (NameListParser.maxTitleLength + 1);
      expect(NameListParser.parse(paragraph), isEmpty);
    });

    test('returns nothing for empty input', () {
      expect(NameListParser.parse(''), isEmpty);
      expect(NameListParser.parse('   \n\n  '), isEmpty);
    });
  });

  group('cleanLine', () {
    test('removes decoration without touching the title', () {
      expect(NameListParser.cleanLine('  • 3) Elden Ring (PS5)  '), 'Elden Ring');
    });

    test('returns empty for a comment line', () {
      expect(NameListParser.cleanLine('# my library'), '');
    });
  });

  group('stripPlatformSuffix', () {
    test('leaves the title when stripping would empty it', () {
      expect(NameListParser.stripPlatformSuffix('PS5'), 'PS5');
    });

    test('leaves a clean title alone', () {
      expect(NameListParser.stripPlatformSuffix('Elden Ring'), 'Elden Ring');
    });
  });
}
