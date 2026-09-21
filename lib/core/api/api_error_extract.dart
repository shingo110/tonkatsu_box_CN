import 'anilist_api.dart';
import 'bangumi_api.dart';
import 'comicvine_api.dart';
import 'douban_api.dart';
import 'fantlab_api.dart';
import 'google_books_api.dart';
import 'hardcover_api.dart';
import 'host_rate_limiter.dart';
import 'igdb_api.dart';
import 'kitsu_api.dart';
import 'kodi_api.dart';
import 'mangabaka_api.dart';
import 'mangadex_api.dart';
import 'musicbrainz_api.dart';
import 'neodb_api.dart';
import 'openlibrary_api.dart';
import 'podcast_index_api.dart';
import 'psn_api.dart';
import 'ra_api.dart';
import 'screenscraper_api.dart';
import 'simkl_api.dart';
import 'steam_api.dart';
import 'steamgriddb_api.dart';
import 'tmdb_api.dart';
import 'tvdb_api.dart';
import 'tvmaze_api.dart';
import 'vndb_api.dart';
import 'weread_api.dart';
import 'taptap_api.dart';
import 'ximalaya_api.dart';

typedef ApiError = ({String message, String? detail});

/// Pulls a user-facing message and optional debug `detail` out of the typed
/// API exceptions. Unknown exception types fall back to `toString()`.
ApiError extractApiError(Exception e) {
  return switch (e) {
    TmdbApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    IgdbApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    AniListApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    MangaBakaApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    ComicVineApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    OpenLibraryApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    VndbApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    SteamGridDbApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    SteamApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    RaApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    GoogleBooksApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    HardcoverApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    FantlabApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    KodiApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    ScreenScraperApiException(:final String message) =>
      (message: message, detail: null),
    SimklApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    DoubanApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    BangumiApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    KitsuApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    MangaDexApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    MusicBrainzApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    NeoDBApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    PodcastIndexApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    PsnApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    TvdbApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    TvMazeApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    WeReadApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    TapTapApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    XimalayaApiException(:final String message, :final String? detail) =>
      (message: message, detail: detail),
    // Raised by our own limiter rather than by a source, so it is the one error
    // here with no per-API wrapper to be unwrapped from.
    HostCooldownException(:final String host, :final int remainingSeconds) => (
        message:
            'Rate limit exceeded for $host. Try again in ${remainingSeconds}s',
        detail: null,
      ),
    _ => (message: e.toString(), detail: null),
  };
}
