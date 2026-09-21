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

  /// The whole library as bare names: what was bought, then what was played,
  /// in that order and de-duplicated.
  ///
  /// Both halves are read, because neither is complete on its own — a game
  /// played from a subscription was never purchased, and a game bought and
  /// never launched is in no play history. They also come from *different
  /// hosts* and fail independently: a tightened privacy setting or a title
  /// Sony never listed can break one while the other is fine, so each is read
  /// best-effort and a failure only becomes an error when nothing at all came
  /// back. Returning the half that worked is a better outcome than returning
  /// none of it, and the user sees the count either way.
  Future<List<String>> fetchLibraryNames({
    required String accessToken,
    void Function(int fetched)? onPage,
  }) async {
    final List<String> names = <String>[];
    final Set<String> seen = <String>{};
    PsnApiException? firstFailure;

    void collect(Iterable<String> values) {
      for (final String value in values) {
        final String name = value.trim();
        if (name.isNotEmpty && seen.add(name.toLowerCase())) names.add(name);
      }
    }

    Future<void> read(Future<Iterable<String>> Function() half) async {
      try {
        collect(await half());
        onPage?.call(names.length);
      } on PsnApiException catch (e) {
        firstFailure ??= e;
      }
    }

    await read(
      () async => (await fetchPurchasedGames(
        accessToken: accessToken,
        onPage: onPage,
      ))
          .map((PsnPurchasedGame game) => game.name),
    );
    await read(
      () async => (await fetchPlayedGames(
        accessToken: accessToken,
        onPage: onPage,
      ))
          .map((PsnPlayedGame game) => game.displayName),
    );

    final PsnApiException? failure = firstFailure;
    if (names.isEmpty && failure != null) throw failure;
    return names;
  }

  void dispose() {
    _auth.dispose();
    _library.dispose();
  }
}
