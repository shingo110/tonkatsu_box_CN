/// Shared between the app's client and the selfhost proxy: the proxy rebuilds
/// the signed path from its own segments, so both ends must spell it the same.
const String kDoubanApiBase = 'https://frodo.douban.com';

/// Search takes a `q`, a `count` and a `start` offset.
const String kDoubanSearchBookPath = '/api/v2/search/book';

/// `/api/v2/book/{id}` and `/api/v2/book/isbn/{isbn}` share this prefix.
const String kDoubanBookPath = '/api/v2/book';

/// Rows the search endpoint answers per call.
const int kDoubanSearchCount = 20;

/// Frodo refuses any other User-Agent before it even looks at the signature,
/// so the client has to wear the shipped app's.
const String kDoubanUserAgent =
    'api-client/1 com.douban.frodo/7.22.0(230) Android/28 product/shark '
    'vendor/Xiaomi model/MI+8 rom/miui6  network/wifi  '
    'udid/8b4b1c3ba0f4c3e4f7b6a2e9c3b6c8f4 platform/mobile';
