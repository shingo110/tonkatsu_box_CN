import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/anilist_api.dart';
import 'package:tonkatsu_box/core/api/api_error_extract.dart';
import 'package:tonkatsu_box/core/api/bangumi_api.dart';
import 'package:tonkatsu_box/core/api/comicvine_api.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';
import 'package:tonkatsu_box/core/api/fantlab_api.dart';
import 'package:tonkatsu_box/core/api/google_books_api.dart';
import 'package:tonkatsu_box/core/api/hardcover_api.dart';
import 'package:tonkatsu_box/core/api/host_rate_limiter.dart';
import 'package:tonkatsu_box/core/api/igdb_api.dart';
import 'package:tonkatsu_box/core/api/kitsu_api.dart';
import 'package:tonkatsu_box/core/api/kodi_api.dart';
import 'package:tonkatsu_box/core/api/mangadex_api.dart';
import 'package:tonkatsu_box/core/api/musicbrainz_api.dart';
import 'package:tonkatsu_box/core/api/neodb_api.dart';
import 'package:tonkatsu_box/core/api/podcast_index_api.dart';
import 'package:tonkatsu_box/core/api/ra_api.dart';
import 'package:tonkatsu_box/core/api/screenscraper_api.dart';
import 'package:tonkatsu_box/core/api/steam_api.dart';
import 'package:tonkatsu_box/core/api/steamgriddb_api.dart';
import 'package:tonkatsu_box/core/api/tmdb_api.dart';
import 'package:tonkatsu_box/core/api/tvdb_api.dart';
import 'package:tonkatsu_box/core/api/tvmaze_api.dart';
import 'package:tonkatsu_box/core/api/vndb_api.dart';
import 'package:tonkatsu_box/core/api/weread_api.dart';

void main() {
  group('extractApiError', () {
    test('pulls message and detail from every typed API exception', () {
      final List<(Exception, String)> cases = <(Exception, String)>[
        (const TmdbApiException('tmdb', detail: 'd1'), 'tmdb'),
        (const IgdbApiException('igdb', detail: 'd2'), 'igdb'),
        (const AniListApiException('anilist', detail: 'd3'), 'anilist'),
        (const VndbApiException('vndb', detail: 'd4'), 'vndb'),
        (const SteamGridDbApiException('sgdb', detail: 'd5'), 'sgdb'),
        (const SteamApiException('steam', detail: 'd6'), 'steam'),
        (const RaApiException('ra', detail: 'd7'), 'ra'),
        (const ComicVineApiException('comicvine', detail: 'd8'), 'comicvine'),
        (const GoogleBooksApiException('gbooks', detail: 'd9'), 'gbooks'),
        (const HardcoverApiException('hardcover', detail: 'd10'), 'hardcover'),
        (const FantlabApiException('fantlab', detail: 'd11'), 'fantlab'),
        (const KodiApiException('kodi', detail: 'd12'), 'kodi'),
        (const BangumiApiException('bangumi', detail: 'd13'), 'bangumi'),
        (const KitsuApiException('kitsu', detail: 'd14'), 'kitsu'),
        (const MangaDexApiException('mangadex', detail: 'd15'), 'mangadex'),
        (const MusicBrainzApiException('mbz', detail: 'd16'), 'mbz'),
        (const NeoDBApiException('neodb', detail: 'd17'), 'neodb'),
        (const PodcastIndexApiException('pci', detail: 'd18'), 'pci'),
        (const TvdbApiException('tvdb', detail: 'd19'), 'tvdb'),
        (const TvMazeApiException('tvmaze', detail: 'd20'), 'tvmaze'),
        (const WeReadApiException('weread', detail: 'd21'), 'weread'),
      ];

      for (final (Exception e, String msg) in cases) {
        final ApiError r = extractApiError(e);
        expect(r.message, msg);
        expect(r.detail, isNotNull);
      }
    });

    test('unwraps every exception the tree declares', () {
      // The case list above is hand-written, so it drifts: NeoDB and Bangumi
      // shipped with no case at all and surfaced their own class names to the
      // user. The tree is the source of truth instead.
      final RegExp decl = RegExp(
        r'^class (\w+Exception) implements Exception',
        multiLine: true,
      );
      final Set<String> declared = <String>{};

      for (final FileSystemEntity e
          in Directory('lib/core/api').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        declared.addAll(
          decl
              .allMatches(e.readAsStringSync())
              .map((RegExpMatch m) => m.group(1)!),
        );
      }

      final String src =
          File('lib/core/api/api_error_extract.dart').readAsStringSync();
      final List<String> unhandled = declared
          .where((String n) => !src.contains(n))
          .toList()
        ..sort();

      expect(declared, isNotEmpty);
      expect(
        unhandled,
        isEmpty,
        reason: 'extractApiError would fall back to toString for these',
      );
    });

    test('keeps a null detail when the exception carries none', () {
      final ApiError r = extractApiError(const TmdbApiException('boom'));
      expect(r.message, 'boom');
      expect(r.detail, isNull);
    });

    test('maps ScreenScraper message without a detail', () {
      final ApiError r = extractApiError(ScreenScraperApiException('ss'));
      expect(r.message, 'ss');
      expect(r.detail, isNull);
    });

    test('maps Douban message and keeps its detail', () {
      final ApiError r = extractApiError(
        const DoubanApiException('db', detail: 'cause'),
      );
      expect(r.message, 'db');
      expect(r.detail, 'cause');
    });

    test('states the wait a host cooldown still owes', () {
      final ApiError r = extractApiError(
        const HostCooldownException('douban.com', Duration(seconds: 240)),
      );

      expect(r.message, contains('douban.com'));
      expect(r.message, contains('240s'));
      expect(r.detail, isNull);
    });

    test('falls back to toString for unknown exception types', () {
      final ApiError r = extractApiError(const FormatException('bad input'));
      expect(r.detail, isNull);
      expect(r.message, contains('bad input'));
    });
  });
}
