# PSN client

## Why this does not look like the other catalogue clients

Every other API in `lib/core/api/` talks to a *public* endpoint. This one does
not: Sony registers no OAuth clients, documents no API, and ships no PIN flow.
Everything below is community reverse engineering, carried by every open-source
PSN client in the same shape. It can break without notice, and that is a
property of the upstream, not a defect here.

## The authorisation, end to end

1. **The user obtains an NPSSO.** Signing in at playstation.com leaves a session
   cookie; `ca.account.sony.com/api/v1/ssocookie` prints it as JSON. This is the
   only step a human performs, and it is why there is no WebView, no deep link
   and no loopback listener anywhere in this package.
2. **`GET /api/authz/v3/oauth/authorize`** with `Cookie: npsso=…` answers
   **302** with `code=…` inside its `Location`. The redirect target is the
   PlayStation App's own scheme, so the response is deliberately *not* followed
   — the code is the whole payload. `exchangeNpssoForCode` reads it out.
3. **`POST /api/authz/v3/oauth/token`** with the fixed Basic pair exchanges the
   code for `access_token` (about an hour) and `refresh_token` (about two
   months).
4. The same endpoint with `grant_type=refresh_token` rolls both forward, which
   is what keeps a remembered session alive without another NPSSO.

## Where the purchase list comes from

`web.np.playstation.com/api/graphql/v1/op`, operation `getPurchasedGameList`,
sent as a **persisted query**: Sony holds the document and the request carries
only the operation name, a sha256 and the variables. That list — not the trophy
list — is what "my PlayStation library" means: `trophyTitles` only covers games
the account has *played* enough to earn a trophy in, and `gamelist/v2` is
per-device.

The response is paged with `size`/`start` and has no total count, so the walk
stops on the first short page, bounded by `kPsnPurchasedMaxPages`.

## The library is two lists, not one

Purchases are half of it. A title played from the PlayStation Plus catalogue was
never bought, so `getPurchasedGameList` cannot know it exists — a subscriber who
finished such a game and earned its platinum trophy would not find it in the
import. The play history is the other half:

| | request | note |
|---|---|---|
| bought | `web.np.playstation.com/api/graphql/v1/op`, persisted `getPurchasedGameList` | GraphQL, sha256-pinned |
| played | `m.np.playstation.com/api/gamelist/v2/users/me/titles` | REST, `limit`/`offset`/`categories` |

The play history is read over REST rather than as the matching
`getUserGameList` persisted query on the store's own host, because only the REST
endpoint returns `localizedName` *and* supports real `offset` paging. It is also
a third Sony domain, hence `ProxyTarget.psnme`.

`PsnApi.fetchLibraryNames` merges the two, purchases first, de-duplicated by
name. They are read **independently on purpose**: different hosts, different
privacy surfaces, so one failing must not cost the user the other half. Only a
run that produced no name at all is reported as an error.

Trophies are deliberately not a third source: `trophyTitles` holds only titles
played far enough to earn something, which the play history already covers.

### The `content-type` header is load-bearing, not cosmetic

Sony's GraphQL host sits behind Apollo's CSRF prevention. A request that carries
**no** `content-type` — or one of `application/x-www-form-urlencoded`,
`multipart/form-data`, `text/plain` — is answered with **400 "blocked as a
potential Cross-Site Request Forgery"** before any token is looked at, unless it
presents `x-apollo-operation-name` or `apollo-require-preflight`.

This call is a **GET with everything in the query string**, so Dio has no body
to infer a type from and sends no `content-type` at all: the first device build
failed here with exactly that 400. `Options(contentType: 'application/json')`
is the fix, and it is the only one of the two accepted escapes that survives the
web proxy — `x-apollo-operation-name` would be dropped, since
`_forwardedRequestHeaders` forwards just `content-type` and `accept`.

Removing that one line breaks the feature on every platform while leaving the
rest of the unit suite green, so `psn_library_client_test.dart` asserts it
directly. It can be reproduced without an account: the CSRF gate runs before
authentication, so a **fake** token against the live endpoint shows the 400
without the header and `200 + invalid_psn_access_token` with it.

## Credential handling

- The **NPSSO is never persisted.** It is spent the moment it arrives and
  cleared from the controller. It is password-equivalent.
- Only the **refresh token** is offered for storage, behind an explicit opt-in
  (`SettingsKeys.psnRememberToken`), and it is the only thing worth storing.
- The **client pair in `packages/core/lib/api/psn_constants.dart` is public**, is
  identical in every open-source PSN client, and is not user-configurable: it
  identifies the application, not the account.

## Three platforms, one flow

Desktop and mobile talk to Sony directly, sending a real `Cookie` and a real
`Authorization: Bearer`. A browser cannot: it refuses to set `Cookie` outright,
and the selfhost proxy forwards only `content-type` and `accept`. On web the
credential therefore rides the URL (`npsso`, `access_token`) and the server's
`_authorize` branch for `ProxyTarget.psnauth` / `psnweb` lifts it back into a
header and drops it from the query. That asymmetry is the whole reason
`psn_constants.dart` lives in `packages/core` rather than under `lib/`.

## Why there is no `ImportSource` here

`ImportSource` adapters resolve *catalogue entries*. PSN resolves nothing — it
returns bare titles, exactly like a pasted list. So this package stops at
`List<String>`, and `GameNameListImportContent` takes over from there via its
`initialNames` parameter. Matching, the confidence thresholds, the review step
and the write are one implementation shared by both entry points; adding a
second `ImportSource` would have duplicated the risky half.
