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
