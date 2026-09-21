import 'game_title_matcher.dart';

/// Turns a pasted block of game names into one catalogue query per line.
///
/// The text arrives from wherever the user could copy it — the PS App's library
/// list, a trophy site's table, a hand-kept note — so the parser only strips
/// what is unambiguously decoration: list markers, wrapping quotes, and a
/// trailing platform tag (`(PS5)`, `- PS4`). Anything else is kept verbatim,
/// because a game title may itself contain punctuation a cleanup pass would
/// eat (`Sid Meier's Civilization VI`, `NieR:Automata`).
class NameListParser {
  /// Shorter than this is a stray glyph, not a title.
  static const int minTitleLength = 2;

  /// Longer than this is a pasted paragraph, not a title.
  static const int maxTitleLength = 180;

  /// `- `, `* `, `• `, `[x] `, `12. `, `12、` at the start of a line. Repeated
  /// so a nested bullet resolves in one pass (`• 3) Elden Ring`).
  static final RegExp _listMarker = RegExp(
    r'^\s*(?:(?:[-*•·–—]\s+|\[[ xX]?\]\s*|\d{1,3}\s*[.)、]\s*))+',
  );

  /// Quotes and brackets some lists wrap every title in.
  static final RegExp _wrappingQuotes = RegExp(
    '^[\'"“”‘’«»「」『』]+|[\'"“”‘’«»「」『』]+\$',
  );

  /// A platform tag in trailing position, bracketed or after a dash. Anchored
  /// at the end so a title merely *containing* `PS5` survives.
  static final RegExp _platformTail = RegExp(
    r'[\s\-–—:：]*[\(\[（【]?\s*'
    r'(?:PS[1-5]|PSVR\s*2?|PS\s*VR\s*2?|PS\s*Vita|PlayStation\s*(?:Vita|Portable|[1-5])|PSP)'
    r'\s*[\)\]）】]?\s*$',
    caseSensitive: false,
  );

  /// A line that is *nothing but* a platform tag — a table header, not a game.
  static final RegExp _platformOnly = RegExp(
    r'^[\s\-–—:：]*[\(\[（【]?\s*'
    r'(?:PS[1-5]|PSVR\s*2?|PS\s*VR\s*2?|PS\s*Vita|PlayStation\s*(?:Vita|Portable|[1-5])|PSP)'
    r'\s*[\)\]）】]?\s*$',
    caseSensitive: false,
  );

  /// At least one letter or CJK/kana/hangul character. Spelled out rather than
  /// `[^\W\d_]` because `\w` in an ECMAScript regex is ASCII-only — that form
  /// would drop every Chinese title.
  static final RegExp _hasLetter = RegExp(
    '[a-z\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]',
    caseSensitive: false,
  );

  /// Titles in input order, de-duplicated on the matcher's normalization so
  /// `God of War` / `god of war` / `God-of-War` collapse into one row.
  static List<String> parse(String input) {
    final List<String> titles = <String>[];
    final Set<String> seen = <String>{};
    for (final String rawLine in input.split('\n')) {
      final String line = cleanLine(rawLine);
      if (!isUsable(line)) continue;
      final String normalized = GameTitleMatcher.normalizeTitle(line);
      // A title of nothing but punctuation normalizes away; fall back to the
      // raw casing so two distinct such lines still don't collide silently.
      final String key = normalized.isEmpty ? line.toLowerCase() : normalized;
      if (!seen.add(key)) continue;
      titles.add(line);
    }
    return titles;
  }

  /// One line with its decoration removed, still possibly empty.
  static String cleanLine(String raw) {
    String line = raw.replaceAll('\uFEFF', '').trim();
    line = line.replaceFirst(_listMarker, '');
    line = line.replaceAll(_wrappingQuotes, '').trim();
    if (_platformOnly.hasMatch(line)) return '';
    line = stripPlatformSuffix(line);
    if (line.startsWith('#')) return '';
    return line.trim();
  }

  /// Drops a trailing platform tag, unless doing so would leave nothing or
  /// nearly nothing — then the original stands.
  static String stripPlatformSuffix(String title) {
    final String stripped = title.replaceFirst(_platformTail, '').trim();
    if (stripped.length < minTitleLength) return title;
    return stripped;
  }

  /// False for blank lines, comment lines, bare numbers and stray digits.
  static bool isUsable(String title) {
    if (title.length < minTitleLength || title.length > maxTitleLength) {
      return false;
    }
    return _hasLetter.hasMatch(title);
  }
}
