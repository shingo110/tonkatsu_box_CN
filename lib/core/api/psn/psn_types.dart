/// PSN is an undocumented, community-reverse-engineered surface: a bad NPSSO,
/// a spent code and a revoked token all come back as a small JSON body with a
/// 4xx, so the body is the only thing worth surfacing to the user.
class PsnApiException implements Exception {
  const PsnApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final String? detail;

  /// Sony answers a rejected NPSSO or a spent code with `invalid_grant`; the
  /// caller turns this into "sign in again" rather than a network error.
  bool get isAuthorizationFailure => statusCode == 400 || statusCode == 401;

  @override
  String toString() => 'PsnApiException: $message';
}

/// The body of `POST /oauth/token`, for both the code exchange and the refresh.
class PsnAuthTokens {
  const PsnAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.refreshTokenExpiresIn,
  });

  factory PsnAuthTokens.fromJson(Map<String, dynamic> json) {
    return PsnAuthTokens(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: (json['refresh_token'] as String?) ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 3600,
      refreshTokenExpiresIn:
          (json['refresh_token_expires_in'] as num?)?.toInt() ?? 0,
    );
  }

  /// The JWT every Sony API call carries as `Bearer`.
  final String accessToken;

  /// Good for about two months; the only thing worth persisting. The NPSSO
  /// that produced it is discarded immediately — it is password-equivalent.
  final String refreshToken;

  /// Seconds until [accessToken] expires (Sony issues roughly an hour).
  final int expiresIn;

  /// Seconds until [refreshToken] expires (roughly two months).
  final int refreshTokenExpiresIn;

  bool get isUsable => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

/// One row of `getPurchasedGameList` — a game the account owns outright or
/// through a subscription.
///
/// The store's GraphQL returns the full purchase history rather than the
/// trophy list, which only holds titles the account has actually *played*.
class PsnPurchasedGame {
  const PsnPurchasedGame({
    required this.name,
    this.titleId,
    this.entitlementId,
    this.conceptId,
    this.imageUrl,
    this.platform,
  });

  factory PsnPurchasedGame.fromJson(Map<String, dynamic> json) {
    // `image` is a nested Media object; a missing or malformed one is not
    // worth failing the row over.
    final Map<String, dynamic>? image =
        json['image'] as Map<String, dynamic>?;
    // `platform` is a GraphQL enum — a plain string in JSON, but nothing here
    // depends on its exact spelling, so anything else is dropped.
    final Object? rawPlatform = json['platform'];

    return PsnPurchasedGame(
      name: (json['name'] as String?) ?? '',
      titleId: json['titleId'] as String?,
      entitlementId: json['entitlementId'] as String?,
      conceptId: json['conceptId'] as String?,
      imageUrl: image?['url'] as String?,
      platform: rawPlatform is String ? rawPlatform : null,
    );
  }

  /// The store's display name, and the only field the matcher consumes.
  final String name;

  /// Sony's per-version id, e.g. `PPSA01284_00`; absent for some entries.
  final String? titleId;

  final String? entitlementId;
  final String? conceptId;
  final String? imageUrl;

  /// `PS4` / `PS5` as the store spells it, or null when absent.
  final String? platform;

  bool get isUsable => name.trim().isNotEmpty;
}

/// One row of `gamelist/v2/users/me/titles` — a title the account has *played*.
///
/// This is the half a purchase list cannot see. A game played from the
/// PlayStation Plus catalogue is in the play history and was never bought, so
/// an import built on `getPurchasedGameList` alone silently drops it — a
/// subscriber who finished a catalogue game and earned its platinum trophy
/// would not find it in their library.
class PsnPlayedGame {
  const PsnPlayedGame({
    required this.name,
    this.localizedName,
    this.titleId,
    this.imageUrl,
    this.category,
  });

  factory PsnPlayedGame.fromJson(Map<String, dynamic> json) {
    final Object? rawCategory = json['category'];
    return PsnPlayedGame(
      name: (json['name'] as String?) ?? '',
      localizedName: json['localizedName'] as String?,
      titleId: json['titleId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      category: rawCategory is String ? rawCategory : null,
    );
  }

  /// Sony's own name for the title, as the store spells it.
  final String name;

  /// The same title in the account's language, when the store has one.
  ///
  /// Only this endpoint returns it — the store's GraphQL has no equivalent —
  /// which is why the play history is read over REST. It is a second spelling
  /// of the same game, so it is what a matcher can use to reach a catalogue in
  /// the other language: the two names, and the two catalogues, are matched on
  /// either side of the script split.
  final String? localizedName;

  /// Sony's per-version id, e.g. `CUSA01433_00`.
  final String? titleId;

  final String? imageUrl;

  /// `ps4_game` / `ps5_native_game` / `pspc_game` / `unknown`.
  final String? category;

  /// The name to hand the matcher: Sony's, falling back to the localized one
  /// only when the first is missing. Deliberately *not* a preference for the
  /// localized spelling — which catalogue to ask is the matcher's decision,
  /// and it makes that decision from the script of the name it is given.
  String get displayName {
    final String plain = name.trim();
    return plain.isNotEmpty ? plain : (localizedName ?? '').trim();
  }

  bool get isUsable => displayName.isNotEmpty;
}
