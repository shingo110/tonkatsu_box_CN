/// TapTap (taptap.cn) web API contract, shared by the app and the selfhost
/// proxy so both ends spell the paths once.
///
/// Keyless: the endpoint asks for no key and no account, only the `X-UA`
/// header below. `/webapiv2/mix-search/v1/by-keyword` — the path older
/// write-ups name — is gone, and `app-search/v1/by-keyword` is the live one.
const String kTapTapHost = 'www.taptap.cn';

/// Keyword search over the app catalogue. Every row is one app.
const String kTapTapSearchPath = '/webapiv2/app-search/v1/by-keyword';

/// Full record for one app id, including the description and the tag list.
const String kTapTapDetailPath = '/webapiv2/app/v4/detail';

/// TapTap answers `400 INVALID_XUA` to any request without this header, so it
/// is part of the contract rather than a nicety. The client identifier inside
/// is the web app's own; no account is attached to it.
const String kTapTapXUa =
    'V=1&PN=WebApp&LANG=zh_CN&VN_CODE=102&VN=0.1.0&LOC=CN&PLT=PC&DS=Android'
    '&UID=97bb961f-bf03-4c7a-8cd7-8d6d8655d9c8&DT=PC&OS=Windows&OSV=10';

/// The endpoint returns ten rows per call and takes an offset, not a page.
const int kTapTapPageSize = 10;

/// TapTap answers any non-empty keyword; an empty one is a 400 (`kw 或者
/// can_buy 必填`) and no browse endpoint exists, so this source searches only.
const int kTapTapMinQueryLength = 1;

/// Lookup results come back ten at a time with no trustworthy total, so paging
/// ends on an empty page. This ceiling only keeps a runaway scroll bounded.
const int kTapTapMaxOffset = 300;

/// TapTap app ids and IGDB game ids share one integer column, and the game
/// unique index carries no `source`, so the two catalogues would collide.
/// A billion-wide offset keeps them apart and stays reversible — the refresh
/// path subtracts it to get the app id back.
const int kTapTapIdOffset = 1000000000;

/// The app's page on taptap.cn, built from the bare id.
String tapTapAppUrl(int appId) => 'https://$kTapTapHost/app/$appId';
