/// Ximalaya (ximalaya.com) web API contract, shared by the app and the
/// selfhost proxy so both ends spell the paths once.
///
/// Keyless. The obvious-looking `/revision/search/main` answers
/// `{"ret":200,"reason":"risk invalid","riskLevel":5}` to anything without a
/// browser session — the site's own front end calls `/revision/search/seo`
/// instead, and that one answers plain JSON. The album detail endpoint is
/// behind a blacklist, so search is the only door this source has.
const String kXimalayaHost = 'www.ximalaya.com';

/// Album search. `core=album` is what keeps tracks out of the result set —
/// this source collects shows, not episodes.
const String kXimalayaSearchPath = '/revision/search/seo';

/// Rows per call; the site's front end asks for thirty.
const int kXimalayaPageSize = 30;

/// An empty keyword answers `ret 404 no such search word` and no browse
/// endpoint exists, so this source searches only.
const int kXimalayaMinQueryLength = 1;

/// `total` and `totalPage` disagree with the rows actually served (201 and 1
/// on a query that kept paging), so paging ends on an empty page. This ceiling
/// only keeps a runaway scroll bounded.
const int kXimalayaMaxPage = 20;

/// Album ids and Douban subject ids are both eight-digit integers heading for
/// the same `collection_items.external_id` column, whose unique index for the
/// audio type carries no `source`. An offset keeps the two catalogues apart;
/// the lookup path subtracts it to get the album id back.
const int kXimalayaIdOffset = 2000000000;

/// Album covers arrive as a bare `storages/...` path on an image CDN.
String ximalayaCoverUrlFor(String? coverPath) {
  final String? path = coverPath?.trim();
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return 'https://imagev2.xmcdn.com/$path';
}

/// The album's page on ximalaya.com, built from the bare album id.
String ximalayaAlbumUrl(int albumId) =>
    'https://$kXimalayaHost/album/$albumId';
