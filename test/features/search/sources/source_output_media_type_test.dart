import 'package:core/models/media_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/features/search/sources/anilist_anime_source.dart';
import 'package:tonkatsu_box/features/search/sources/anilist_manga_source.dart';
import 'package:tonkatsu_box/features/search/sources/bangumi_anime_source.dart';
import 'package:tonkatsu_box/features/search/sources/fantlab_source.dart';
import 'package:tonkatsu_box/features/search/sources/igdb_games_source.dart';
import 'package:tonkatsu_box/features/search/sources/neodb_book_source.dart';
import 'package:tonkatsu_box/features/search/sources/neodb_movie_source.dart';
import 'package:tonkatsu_box/features/search/sources/neodb_tv_source.dart';
import 'package:tonkatsu_box/features/search/sources/openlibrary_source.dart';
import 'package:tonkatsu_box/features/search/sources/tmdb_anime_source.dart';
import 'package:tonkatsu_box/features/search/sources/tmdb_movies_source.dart';
import 'package:tonkatsu_box/features/search/sources/tmdb_tv_source.dart';
import 'package:tonkatsu_box/features/search/sources/vndb_source.dart';

void main() {
  group('SearchSource.outputMediaType', () {
    test('TmdbMoviesSource → MediaType.movie', () {
      expect(TmdbMoviesSource().outputMediaType, MediaType.movie);
    });

    test('TmdbTvSource → MediaType.tvShow', () {
      expect(TmdbTvSource().outputMediaType, MediaType.tvShow);
    });

    test('TmdbAnimeSource → MediaType.animation', () {
      expect(TmdbAnimeSource().outputMediaType, MediaType.animation);
    });

    test('IgdbGamesSource → MediaType.game', () {
      expect(IgdbGamesSource().outputMediaType, MediaType.game);
    });

    test('AniListAnimeSource → MediaType.anime', () {
      expect(AniListAnimeSource().outputMediaType, MediaType.anime);
    });

    test('AniListMangaSource → MediaType.manga', () {
      expect(AniListMangaSource().outputMediaType, MediaType.manga);
    });

    test('BangumiAnimeSource → MediaType.anime', () {
      expect(BangumiAnimeSource().outputMediaType, MediaType.anime);
    });

    test('VndbSource → MediaType.visualNovel', () {
      expect(VndbSource().outputMediaType, MediaType.visualNovel);
    });

    test('OpenLibrarySource → MediaType.book', () {
      expect(OpenLibrarySource().outputMediaType, MediaType.book);
    });

    test('FantlabSource → MediaType.book', () {
      expect(FantlabSource().outputMediaType, MediaType.book);
    });

    test('NeoDBBookSource → MediaType.book', () {
      expect(NeoDBBookSource().outputMediaType, MediaType.book);
    });

    test('NeoDBMovieSource → MediaType.movie', () {
      expect(NeoDBMovieSource().outputMediaType, MediaType.movie);
    });

    test('NeoDBTvSource → MediaType.tvShow', () {
      expect(NeoDBTvSource().outputMediaType, MediaType.tvShow);
    });
  });
}
