import 'package:core/models/audio_item.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ximalaya/ximalaya_http_client.dart';
import 'ximalaya/ximalaya_search_api.dart';

export 'ximalaya/ximalaya_types.dart';

final Provider<XimalayaApi> ximalayaApiProvider =
    Provider<XimalayaApi>((Ref ref) => XimalayaApi());

/// Ximalaya (ximalaya.com) facade — the mainland audio platform, and the one
/// podcast catalogue here that reaches Chinese shows, audio dramas and radio
/// plays without a proxy. Keyless, search-only: the album detail endpoint
/// answers a blacklist page to an anonymous client.
class XimalayaApi {
  XimalayaApi({Dio? dio}) : _client = XimalayaHttpClient(dio: dio) {
    _search = XimalayaSearchApi(_client);
  }

  final XimalayaHttpClient _client;
  late final XimalayaSearchApi _search;

  Future<(List<AudioItem>, bool hasMore, int totalPages)> searchPodcasts({
    required String query,
    required int page,
  }) =>
      _search.searchPodcasts(query: query, page: page);

  /// No by-id door is open, so a stored album comes back through a title
  /// search matched on album id. Null when the title no longer surfaces it.
  Future<AudioItem?> findByNativeId({
    required String title,
    required String nativeId,
  }) =>
      _search.findByNativeId(title: title, nativeId: nativeId);

  void dispose() => _client.dispose();
}
