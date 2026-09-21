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

  void dispose() {
    _auth.dispose();
    _library.dispose();
  }
}
