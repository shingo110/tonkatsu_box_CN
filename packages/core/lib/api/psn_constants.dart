/// Shared between the app's client and the selfhost proxy: the browser cannot
/// reach Sony's hosts itself (no CORS header, and the credential rides a
/// header the proxy refuses to forward), so both ends must spell these the
/// same way, exactly as `douban_constants.dart` does for Frodo.
library;

/// Sony's account host. `/oauth/authorize` mints a code from an NPSSO cookie;
/// `/oauth/token` exchanges a code — or later a refresh token — for a JWT.
const String kPsnAuthBase = 'https://ca.account.sony.com';

const String kPsnAuthorizePath = '/api/authz/v3/oauth/authorize';

const String kPsnTokenPath = '/api/authz/v3/oauth/token';

/// Page that prints the caller's NPSSO as JSON once they are signed in to
/// playstation.com in the same browser.
const String kPsnNpssoPagePath = '/api/v1/ssocookie';

/// Sign-in landing page used when the caller is *not* signed in — the app
/// opens it in a browser so the user can obtain an NPSSO.
const String kPsnSignInUrl = 'https://my.account.sony.com/central/signin/';

/// The PlayStation App's client pair.
///
/// Sony runs no OAuth registration for third-party clients, so every open
/// source PSN client authenticates as the mobile app and carries these two
/// public constants. The account is guarded by the user's own NPSSO; this pair
/// identifies the *application*, and leaks nothing a reader of `psn-api` could
/// not already read. It is deliberately not user-configurable: one wrong byte
/// here is an opaque `invalid_grant`, and no user has a better value.
const String kPsnClientId = '09515159-7237-4370-9b40-3806e67c0891';

const String kPsnClientSecret = 'ucPjka5tnrB2KqsP';

/// `Basic base64(clientId:clientSecret)`, precomputed so the client and the
/// proxy send byte-identical headers without either re-encoding.
const String kPsnBasicAuth = 'Basic '
    'MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A=';

/// The redirect the PlayStation App registers. Nothing is listening on it —
/// the code is read out of the `Location` header without following it, which
/// is also why this flow needs no deep link, no WebView and no loopback port.
const String kPsnRedirectUri = 'com.scee.psxandroid.scecompcall://redirect';

/// Asked for at `authorize` and repeated verbatim at the refresh call; a
/// refresh that requests a different set is rejected.
const String kPsnScope = 'psn:mobile.v2.core psn:clientapp';

/// The web store's GraphQL host — the only endpoint that exposes what the
/// account has *bought*, as opposed to what it has played or earned trophies
/// for.
const String kPsnWebBase = 'https://web.np.playstation.com';

const String kPsnGraphqlPath = '/api/graphql/v1/op';

/// A persisted-query name and its sha256: the document itself is registered
/// server-side, so the request carries only the hash and the variables.
const String kPsnPurchasedGameListOperation = 'getPurchasedGameList';

const String kPsnPurchasedGameListHash =
    '827a423f6a8ddca4107ac01395af2ec0eafd8396fc7fa204aaf9b7ed2eefa168';

/// Rows the store answers per page; the list is walked until a short page.
const int kPsnPurchasedPageSize = 24;

/// Stop after this many pages. 40 × 24 = 960 titles, well past any real
/// library, and it keeps a misbehaving upstream from looping forever.
const int kPsnPurchasedMaxPages = 40;

/// Query parameter the *web* client smuggles its NPSSO in. The proxy forwards
/// only `content-type` and `accept`, so a credential past that allowlist has
/// to travel in the URL and be lifted into a header server-side. Desktop and
/// mobile builds never use it — they send a real `Cookie` header.
const String kPsnNpssoParam = 'npsso';

/// The same trick for the access token the library call needs.
const String kPsnAccessTokenParam = 'access_token';
