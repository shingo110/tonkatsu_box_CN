import 'package:core/models/anime.dart';
import 'package:core/models/manga.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bangumi/bangumi_http_client.dart';
import 'bangumi/bangumi_search_api.dart';
import 'bangumi/bangumi_types.dart';

export 'bangumi/bangumi_types.dart';

final Provider<BangumiApi> bangumiApiProvider =
    Provider<BangumiApi>((Ref ref) => BangumiApi());

/// Bangumi (bgm.tv) REST facade — the only anime catalog here with Chinese
/// titles. Keyless; a descriptive User-Agent is required by Cloudflare.
class BangumiApi {
  BangumiApi({Dio? dio}) : _client = BangumiHttpClient(dio: dio) {
    _search = BangumiSearchApi(_client);
  }

  final BangumiHttpClient _client;
  late final BangumiSearchApi _search;

  Future<(List<Anime>, bool hasMore, int totalPages)> browseAnime({
    String? query,
    List<String>? tags,
    List<String>? metaTags,
    List<String>? airDate,
    List<String>? rating,
    List<String>? rank,
    String sort = kBangumiSortMatch,
    int page = 1,
    int perPage = 20,
  }) =>
      _search.searchSubjects<Anime>(
        parse: Anime.fromBangumi,
        query: query,
        tags: tags,
        metaTags: metaTags,
        airDate: airDate,
        rating: rating,
        rank: rank,
        sort: sort,
        page: page,
        perPage: perPage,
      );

  /// The manga tab of the same endpoint. `type: [1]` alone would mix novels
  /// and picture books in, so the 漫画 meta tag rides along; Bangumi ANDs a
  /// meta tag list, so a caller's extra tags narrow rather than widen.
  Future<(List<Manga>, bool hasMore, int totalPages)> browseManga({
    String? query,
    List<String>? metaTags,
    List<String>? airDate,
    List<String>? rating,
    List<String>? rank,
    String sort = kBangumiSortMatch,
    int page = 1,
    int perPage = 20,
  }) =>
      _search.searchSubjects<Manga>(
        parse: Manga.fromBangumi,
        subjectType: kBangumiBookSubjectType,
        query: query,
        metaTags: <String>[
          kBangumiMangaMetaTag,
          ...?metaTags,
        ],
        airDate: airDate,
        rating: rating,
        rank: rank,
        sort: sort,
        page: page,
        perPage: perPage,
      );

  Future<Anime?> getAnimeById(int id) =>
      _search.getSubject<Anime>(id, Anime.fromBangumi);

  Future<Manga?> getMangaById(int id) =>
      _search.getSubject<Manga>(id, Manga.fromBangumi);

  void dispose() => _client.dispose();
}
