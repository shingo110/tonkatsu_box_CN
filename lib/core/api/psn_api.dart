import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'psn/psn_auth_client.dart';
import 'psn/psn_library_client.dart';
import 'psn/psn_types.dart';

export 'psn/psn_types.dart';

final Provider<PsnApi> psnApiProvider =
    Provider<PsnApi>((Ref ref) => PsnApi());

/// PlayStation Network facade backing the library import.
///
/// PSN registers no OAuth clients and offers no PIN flow, so this is the whole
/// authorisation: the user signs in at playstation.com, copies the NPSSO their
/// account page prints as JSON, and the app trades it for an hour-long JWT plus
/// a refresh token worth about two months. The NPSSO itself is dropped as soon
/// as it has been spent — it is equivalent to the account password.
class PsnApi {
  PsnApi({Dio? authDio, Dio? libraryDio})
      : _auth = PsnAuthClient(dio: authDio),
        _library = PsnLibraryClient(dio: libraryDio);

  final PsnAuthClient _auth;
  final PsnLibraryClient _library;

  /// The full sign-in, NPSSO → code → tokens.
  Future<PsnAuthTokens> connect(String npsso) async {
    final String code = await _auth.exchangeNpssoForCode(npsso);
    return _auth.exchangeCodeForTokens(code);
  }

  /// Keeps a connected account alive without a fresh NPSSO.
  Future<PsnAuthTokens> refresh(String refreshToken) =>
      _auth.refresh(refreshToken);

  /// The games the account owns, newest purchase first.
  Future<List<PsnPurchasedGame>> fetchPurchasedGames({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) =>
      _library.fetchPurchasedGames(accessToken: accessToken, onPage: onPage);

  /// The games the account has played, newest first — the half that includes
  /// titles played from the PlayStation Plus catalogue.
  Future<List<PsnPlayedGame>> fetchPlayedGames({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) =>
      _library.fetchPlayedGames(accessToken: accessToken, onPage: onPage);

  /// The whole library as rows to match: what was bought, then what was played,
  /// in that order and de-duplicated by name.
  ///
  /// Both halves are read, because neither is complete on its own — a game
  /// played from a subscription was never purchased, and a game bought and
  /// never launched is in no play history. They also come from *different
  /// hosts* and fail independently: a tightened privacy setting or a title
  /// Sony never listed can break one while the other is fine, so each is read
  /// best-effort and a failure only becomes an error when nothing at all came
  /// back. Returning the half that worked is a better outcome than returning
  /// none of it, and the user sees the count either way.
  ///
  /// Rows carry their other spellings, which is how a title Sony names in
  /// English can still be found in a Chinese catalogue.
  Future<List<PsnLibraryTitle>> fetchLibraryTitles({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) async {
    final List<PsnLibraryTitle> titles = <PsnLibraryTitle>[];
    final Map<String, int> indexByName = <String, int>{};
    PsnApiException? firstFailure;

    void collect(Iterable<PsnLibraryTitle> incoming) {
      for (final PsnLibraryTitle title in incoming) {
        final String name = title.name.trim();
        if (name.isEmpty) continue;
        final String key = name.toLowerCase();
        final int? existing = indexByName[key];
        if (existing == null) {
          indexByName[key] = titles.length;
          titles.add((name: name, aliases: cleanAliases(title.aliases, name)));
          continue;
        }
        // A game that was both bought and played is one line, and the play
        // history is the half that knows its localized name.
        final PsnLibraryTitle current = titles[existing];
        final List<String> merged =
            cleanAliases(<String>[...current.aliases, ...title.aliases], name);
        if (merged.length != current.aliases.length) {
          titles[existing] = (name: current.name, aliases: merged);
        }
      }
    }

    Future<void> read(Future<Iterable<PsnLibraryTitle>> Function() half) async {
      try {
        collect(await half());
        onPage?.call(titles.length);
      } on PsnApiException catch (e) {
        firstFailure ??= e;
      }
    }

    await read(
      () async => (await fetchPurchasedGames(
        accessToken: accessToken,
        onPage: onPage,
      ))
          // The store's purchase list has no localized name to offer.
          .map((PsnPurchasedGame game) =>
              (name: game.name, aliases: const <String>[])),
    );
    await read(
      () async => (await fetchPlayedGames(
        accessToken: accessToken,
        onPage: onPage,
      ))
          .map((PsnPlayedGame game) => (
                name: game.displayName,
                aliases: <String>[
                  if (game.localizedName != null) game.localizedName!,
                ],
              )),
    );

    final PsnApiException? failure = firstFailure;
    if (titles.isEmpty && failure != null) throw failure;
    return titles;
  }

  void dispose() {
    _auth.dispose();
    _library.dispose();
  }
}

/// Trims spellings, drops blanks and duplicates, and drops the one that merely
/// repeats [name] — the matcher would otherwise spend a request on it.
List<String> cleanAliases(Iterable<String> raw, String name) {
  final Set<String> seen = <String>{name.trim().toLowerCase()};
  final List<String> kept = <String>[];
  for (final String value in raw) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;
    kept.add(trimmed);
  }
  return kept;
}
