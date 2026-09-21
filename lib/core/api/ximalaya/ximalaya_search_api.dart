import 'package:core/api/ximalaya_constants.dart';
import 'package:core/models/audio_item.dart';
import 'package:dio/dio.dart';

import '../api_dio.dart';
import 'ximalaya_http_client.dart';
import 'ximalaya_types.dart';

/// Ximalaya album search. Keyless and search-only: the album detail endpoint
/// answers a blacklist page to an anonymous client, so a row here is the whole
/// record and a stored album is recovered by searching its title again.
class XimalayaSearchApi {
  XimalayaSearchApi(this._client);

  final XimalayaHttpClient _client;

  /// Page numbers, unlike WeRead's offsets. `total` and `totalPage` contradict
  /// the rows actually served (201 and 1 on a query that kept paging), so an
  /// empty page ends the run and [kXimalayaMaxPage] bounds it.
  Future<(List<AudioItem>, bool hasMore, int totalPages)> searchPodcasts({
    required String query,
    required int page,
  }) async {
    try {
      final Response<dynamic> resp = await _client.get(
        kXimalayaSearchPath,
        queryParameters: <String, dynamic>{
          'core': 'album',
          'kw': query,
          'page': page,
          'rows': kXimalayaPageSize,
          'spellchecker': 'true',
          'condition': 'relation',
          'device': 'iPhone',
        },
      );
      final List<AudioItem> albums = _parseAlbums(decodeJsonBody(resp.data));
      final bool hasMore = albums.isNotEmpty && page < kXimalayaMaxPage;
      return (albums, hasMore, hasMore ? page + 1 : page);
    } on DioException catch (e) {
      throw _client.handleDioException(e, 'Failed to search Ximalaya');
    }
  }

  /// Row lookup for the refresh path. The album endpoint is closed, but an
  /// exact title search returns the wanted album, so the title is searched
  /// again and the row matched on album id.
  Future<AudioItem?> findByNativeId({
    required String title,
    required String nativeId,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final (List<AudioItem> albums, _, _) = await searchPodcasts(
      query: trimmed,
      page: 1,
    );
    for (final AudioItem album in albums) {
      if (album.nativeId == nativeId) return album;
    }
    return null;
  }

  /// The payload nests rows under `data.album.docs`. A non-200 `ret` carries a
  /// reason in `msg` — `no such search word`, `risk invalid` — which is worth
  /// surfacing rather than showing as an empty page.
  List<AudioItem> _parseAlbums(Object? data) {
    if (data is! Map<String, dynamic>) return const <AudioItem>[];
    final Object? ret = data['ret'];
    if (ret is num && ret.toInt() != 200) {
      throw XimalayaApiException(
        (data['msg'] as String?) ?? 'Ximalaya refused the search',
      );
    }
    final Object? payload = data['data'];
    if (payload is! Map<String, dynamic>) return const <AudioItem>[];
    final Object? album = payload['album'];
    if (album is! Map<String, dynamic>) return const <AudioItem>[];
    final Object? docs = album['docs'];
    if (docs is! List<dynamic>) return const <AudioItem>[];

    final List<AudioItem> albums = <AudioItem>[];
    for (final Object? row in docs) {
      if (row is! Map<String, dynamic>) continue;
      try {
        albums.add(AudioItem.fromXimalaya(row));
      } on Object {
        continue;
      }
    }
    return albums;
  }
}
