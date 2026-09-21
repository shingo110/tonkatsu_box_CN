/// Confidence bands for a name-list match, driving the preview UI's colour.
enum MatchQuality {
  /// Byte-for-byte identical after trimming and case folding.
  exact,

  /// Same title once punctuation, spacing and case are dropped.
  strong,

  /// The query starts a longer title (`God of War` → `God of War Ragnarök`).
  fair,

  /// Only a similarity heuristic fired — offered, never preselected.
  weak,

  /// Nothing usable came back from the catalogue.
  none,
}

/// Title similarity for name-list matching.
///
/// Deliberately not the RetroAchievements normalizer in `RaToIgdbMapper.normalize`:
/// that one keeps `[a-z0-9]` only, which erases a Chinese title down to the
/// empty string. A PlayStation library read off a Chinese account is mostly
/// Chinese titles, so this normalizer keeps CJK, kana and hangul, and scores
/// short strings by character bigrams rather than word matching.
///
/// The thresholds below are not guesswork — they come from running the real
/// Chinese PlayStation catalogue (see `probe/ps5_name_match_probe.py`), where
/// every false positive shared one trait: the query appeared *inside* a longer
/// title, or the only thing tying the two together was character overlap.
/// Both patterns are therefore capped below [confidentScore] and can only ever
/// be a suggestion the user accepts, never a silent replacement.
class GameTitleMatcher {
  /// Identical after trimming + case folding.
  static const int exactScore = 100;

  /// Identical after [normalizeTitle].
  static const int normalizedScore = 95;

  /// Base for "the query starts a longer title", scaled up by how much of the
  /// longer title the query covers.
  static const int containsBaseScore = 70;

  /// Ceiling for a query found inside a longer title but *not* at its start.
  ///
  /// Real case: TapTap answers `血源诅咒` with `樱花女校：血源诅咒`, a different
  /// game that merely borrows the word. Extension only means "same franchise"
  /// when it is appended — `最后生还者` → `最后生还者 第二部`.
  static const int nestedCeilingScore = 55;

  /// Bigram-overlap band, floor to span. The two add up to 61, one point under
  /// [confidentScore] on purpose: a Dice-only match is a suggestion, never an
  /// answer. Real case: TapTap answers `战神` with `烈火战神`, a mobile title
  /// sharing only the word.
  static const int diceFloorScore = 30;
  static const int diceSpanScore = 31;

  /// Below this the match is [MatchQuality.none]: the row lands in the text
  /// wishlist instead of silently claiming a wrong game.
  static const int confidentScore = 62;

  /// Shortest normalized title allowed to match by containment — without it a
  /// one-character query matches every candidate on the page.
  static const int minContainmentLength = 3;

  /// Fewer bigrams than this makes the coefficient noise, not signal. One is
  /// allowed on purpose: a two-character Chinese title (`战神`) yields a single
  /// gram, and refusing it would drop every short Chinese name.
  static const int minBigrams = 1;

  /// Everything that is not a letter, a digit, CJK, kana or hangul.
  static final RegExp _dropped = RegExp(
    '[^a-z0-9'
    '\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff' // CJK + compatibility
    '\u3040-\u309f\u30a0-\u30ff' // hiragana + katakana
    '\uac00-\ud7af' // hangul syllables
    ']',
  );

  /// Han characters only, no kana/hangul: decides which catalogue to ask first.
  static final RegExp _han =
      RegExp('[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]');

  /// True when the title needs a Chinese catalogue to be found at all.
  static bool hasHan(String title) => _han.hasMatch(title);

  /// Lowercases and strips everything that carries no identity: punctuation,
  /// spacing, trademark marks, decorative brackets.
  static String normalizeTitle(String title) =>
      title.toLowerCase().replaceAll(_dropped, '');

  /// Character-bigram bags over the normalized title, so the coefficient is
  /// script-agnostic (Chinese has no spaces to split on).
  ///
  /// Built as an immutable literal rather than an empty set that is filled in:
  /// the empty form is const-able, so the analyzer demands a `const` set, which
  /// would then reject every `add`.
  static Set<String> bigrams(String normalized) {
    final List<int> runes = normalized.runes.toList();
    if (runes.isEmpty) return const <String>{};
    if (runes.length == 1) return <String>{String.fromCharCodes(runes)};
    return <String>{
      for (int i = 0; i + 1 < runes.length; i++)
        String.fromCharCodes(runes.sublist(i, i + 2)),
    };
  }

  /// Overlap between two bigram bags; 0 when either side is empty.
  static double diceCoefficient(Set<String> a, Set<String> b) {
    if (a.length < minBigrams || b.length < minBigrams) return 0;
    int shared = 0;
    for (final String gram in a) {
      if (b.contains(gram)) shared++;
    }
    return 2 * shared / (a.length + b.length);
  }

  /// 0-100 confidence that [candidate] is the game [query] names.
  static int score(String query, String candidate) {
    final String left = query.trim();
    final String right = candidate.trim();
    if (left.isEmpty || right.isEmpty) return 0;

    if (left.toLowerCase() == right.toLowerCase()) return exactScore;

    final String normalizedLeft = normalizeTitle(left);
    final String normalizedRight = normalizeTitle(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) return 0;
    if (normalizedLeft == normalizedRight) return normalizedScore;

    final bool leftIsShorter = normalizedLeft.length <= normalizedRight.length;
    final int shorter =
        leftIsShorter ? normalizedLeft.length : normalizedRight.length;
    final int longer =
        leftIsShorter ? normalizedRight.length : normalizedLeft.length;

    final bool contains = normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft);
    if (shorter >= minContainmentLength && contains) {
      final bool startsTheLongerOne = leftIsShorter
          ? normalizedRight.startsWith(normalizedLeft)
          : normalizedLeft.startsWith(normalizedRight);
      if (startsTheLongerOne) {
        // Full coverage of the shorter title ranks just under an exact hit.
        const int span = normalizedScore - 1 - containsBaseScore;
        return containsBaseScore + span * shorter ~/ longer;
      }
      // The query is buried inside a longer title, which is how clone apps
      // name themselves. Shown, never chosen.
      return nestedCeilingScore;
    }

    final double dice = diceCoefficient(
      bigrams(normalizedLeft),
      bigrams(normalizedRight),
    );
    if (dice <= 0) return 0;

    final int scaled = (diceFloorScore + dice * diceSpanScore).round();
    return scaled > normalizedScore ? normalizedScore : scaled;
  }

  static MatchQuality qualityOf(int score) {
    if (score >= exactScore) return MatchQuality.exact;
    if (score >= normalizedScore) return MatchQuality.strong;
    if (score >= 80) return MatchQuality.fair;
    if (score >= diceFloorScore) return MatchQuality.weak;
    return MatchQuality.none;
  }

  /// The candidate a row preselects, or null when nothing is confident enough
  /// to be right by default.
  static int bestIndex(String query, List<String> candidateTitles) {
    int bestScore = 0;
    int bestIndex = -1;
    for (int i = 0; i < candidateTitles.length; i++) {
      final int candidateScore = score(query, candidateTitles[i]);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
        bestIndex = i;
      }
    }
    return bestScore >= confidentScore ? bestIndex : -1;
  }
}
