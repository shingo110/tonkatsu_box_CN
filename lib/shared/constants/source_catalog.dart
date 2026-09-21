import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';

/// Whether a data source needs the user to supply an API key.
enum SourceKeyRequirement { none, recommended, mandatory }

/// Where a provider is hosted, which decides whether a mainland-China network
/// can reach it at all.
enum SourceRegion {
  /// Hosted in mainland China; reachable with no extra routing.
  domestic,

  /// Hosted abroad. Cloudflare-fronted Chinese-language catalogues sit here
  /// too: the metadata is Chinese, the route is not.
  overseas,
}

/// Presentation metadata for one data provider. Branding (label, color, logo)
/// lives on [DataSource]; this adds media types, URL and key requirement.
class SourceInfo {
  const SourceInfo({
    required this.source,
    required this.mediaTypes,
    required this.url,
    required this.apiHost,
    required this.region,
    this.keyRequirement = SourceKeyRequirement.none,
  });

  final DataSource source;
  final List<MediaType> mediaTypes;
  final String url;

  /// Bare host the API client talks to, so the connectivity check knows where
  /// to knock. Separate from [url] because the site and the API differ.
  final String apiHost;

  final SourceRegion region;
  final SourceKeyRequirement keyRequirement;

  /// True when a mainland-China network reaches this provider unproxied.
  bool get isDomestic => region == SourceRegion.domestic;
}

/// One entry per search provider, in search-tab order; the wizard and Credits
/// render from it too. SteamGridDB and VGMaps are absent — not searchable.
///
/// Order is load-bearing: the first entry of a media type is its primary.
/// [region] is required so a new provider cannot ship unclassified; the audit
/// behind each value is `probe/host_reachability_audit.py`.
const List<SourceInfo> kDataSourceCatalog = <SourceInfo>[
  SourceInfo(
    source: DataSource.tmdb,
    mediaTypes: <MediaType>[
      MediaType.movie,
      MediaType.tvShow,
      MediaType.animation,
    ],
    url: 'https://www.themoviedb.org/',
    apiHost: 'api.themoviedb.org',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.recommended,
  ),
  SourceInfo(
    source: DataSource.tvmaze,
    mediaTypes: <MediaType>[MediaType.tvShow],
    url: 'https://www.tvmaze.com/',
    apiHost: 'api.tvmaze.com',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.tvdb,
    mediaTypes: <MediaType>[
      MediaType.movie,
      MediaType.tvShow,
    ],
    url: 'https://thetvdb.com/',
    apiHost: 'api4.thetvdb.com',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.mandatory,
  ),
  SourceInfo(
    source: DataSource.igdb,
    mediaTypes: <MediaType>[MediaType.game],
    url: 'https://www.igdb.com/',
    apiHost: 'api.igdb.com',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.recommended,
  ),
  SourceInfo(
    source: DataSource.anilist,
    mediaTypes: <MediaType>[
      MediaType.anime,
      MediaType.manga,
    ],
    url: 'https://anilist.co/',
    apiHost: 'graphql.anilist.co',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.bangumi,
    mediaTypes: <MediaType>[
      MediaType.anime,
      MediaType.manga,
    ],
    url: 'https://bgm.tv/',
    apiHost: 'api.bgm.tv',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.mangabaka,
    mediaTypes: <MediaType>[MediaType.manga],
    url: 'https://mangabaka.org/',
    apiHost: 'api.mangabaka.org',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.mangadex,
    mediaTypes: <MediaType>[MediaType.manga],
    url: 'https://mangadex.org/',
    apiHost: 'api.mangadex.org',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.kitsu,
    mediaTypes: <MediaType>[
      MediaType.anime,
      MediaType.manga,
    ],
    url: 'https://kitsu.io/',
    apiHost: 'kitsu.io',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.vndb,
    mediaTypes: <MediaType>[MediaType.visualNovel],
    url: 'https://vndb.org/',
    apiHost: 'api.vndb.org',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.neodb,
    mediaTypes: <MediaType>[
      MediaType.book,
      MediaType.movie,
      MediaType.tvShow,
    ],
    url: 'https://neodb.social/',
    apiHost: 'neodb.social',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.weread,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://weread.qq.com/',
    apiHost: 'weread.qq.com',
    region: SourceRegion.domestic,
  ),
  // One account covers all three media types, so the link is the site root
  // rather than the books subsection. Every request is signed, but with the
  // public pair the build ships, so there is nothing for a user to enter.
  SourceInfo(
    source: DataSource.douban,
    mediaTypes: <MediaType>[
      MediaType.book,
      MediaType.movie,
      MediaType.tvShow,
      MediaType.anime,
    ],
    url: 'https://www.douban.com/',
    apiHost: 'frodo.douban.com',
    region: SourceRegion.domestic,
  ),
  SourceInfo(
    source: DataSource.openLibrary,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://openlibrary.org/',
    apiHost: 'openlibrary.org',
    region: SourceRegion.overseas,
  ),
  SourceInfo(
    source: DataSource.fantlab,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://fantlab.ru/',
    apiHost: 'api.fantlab.ru',
    region: SourceRegion.overseas,
  ),
  // "Get a key" link target: the Cloud Console page to enable the Books API.
  SourceInfo(
    source: DataSource.googleBooks,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://console.cloud.google.com/apis/library/books.googleapis.com',
    apiHost: 'www.googleapis.com',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.recommended,
  ),
  // "Get a key" link target: the account page with the personal token.
  SourceInfo(
    source: DataSource.hardcover,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://hardcover.app/account/api',
    apiHost: 'api.hardcover.app',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.mandatory,
  ),
  SourceInfo(
    source: DataSource.comicVine,
    mediaTypes: <MediaType>[MediaType.book],
    url: 'https://comicvine.gamespot.com/api/',
    apiHost: 'comicvine.gamespot.com',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.recommended,
  ),
  SourceInfo(
    source: DataSource.musicBrainz,
    mediaTypes: <MediaType>[MediaType.audio],
    url: 'https://musicbrainz.org/',
    apiHost: 'musicbrainz.org',
    region: SourceRegion.overseas,
  ),
  // "Get a key" link target: free registration hands out the key/secret pair.
  SourceInfo(
    source: DataSource.podcastIndex,
    mediaTypes: <MediaType>[MediaType.audio],
    url: 'https://api.podcastindex.org/',
    apiHost: 'api.podcastindex.org',
    region: SourceRegion.overseas,
    keyRequirement: SourceKeyRequirement.recommended,
  ),
];

/// Catalog entry for [source], or null when it is not a search provider.
SourceInfo? sourceInfoFor(DataSource source) {
  for (final SourceInfo info in kDataSourceCatalog) {
    if (info.source == source) return info;
  }
  return null;
}

/// Whether [source] may be expected to answer a mainland-China network with no
/// proxy. An uncatalogued source counts as overseas: nothing gets to assume
/// reachability.
bool isDomesticSource(DataSource source) =>
    sourceInfoFor(source)?.isDomestic ?? false;
