# Interest records and the standalone backend

The native editor now matches a small bundled catalog asynchronously. Its checked
source snapshots are explicitly described as a local catalog, never live API
verification. Arbitrary typed drafts and backstory remain private. Selecting a
record identifies an interest; it is not endorsement, moderation or child safety
approval. A future account release must handle those decisions separately.

## What runs now

`npm run dev:interests` starts the dependency-free Node 24 service on
`127.0.0.1:4318`. It exposes authenticated developer-preview routes, with a closed
503 default when configuration is absent. It is separate from the protected app;
no account, OAuth flow or protected-child query upload is enabled.

Use [Configure Interest Backend](../../script/Configure%20Interest%20Backend.command)
for a masked local prompt, or create a **private**, gitignored `.env.interests`
file with mode 0600 in the repo,
or supply existing server environment variables. Do not paste keys into chat,
put them in an app bundle, or commit them. This work does not create keys.

Required developer-preview configuration:

| Variable | Purpose |
| --- | --- |
| `INTEREST_PREVIEW_ENABLED=true` | Explicitly opens the developer preview only. |
| `INTEREST_PREVIEW_ACCESS_KEY` | Existing server-only preview access secret, at least 24 characters. Never a shipped-app credential. |
| `JEV_API_KEY` | Nathan's existing TypeSafe key. Optional until securely connected. |
| `JEV_MODEL=jev-1.13.0` | Pinned default; review model changes rather than silently drifting. |
| `INTEREST_REVIEWED_PROVIDERS` | Comma-separated providers reviewed for this particular preview/use. Empty default makes **no provider requests**. This configuration is an operational assertion, not proof of legal permission. |
| `INTEREST_CACHE_FILE` | Optional canonical-record archive. Local default is `.prototype-build/interests/canonical-cache.json`. Do not use an ephemeral serverless filesystem as a shared durable database. |
| `INTEREST_ALLOWED_ORIGIN` | Exact allowed browser origin on hosted adapters; no wildcard CORS. Local server sets its loopback origin. |

Routes:

| Method and route | Input and behavior |
| --- | --- |
| `GET /api/interests/status` | Configuration states, with no secrets; distinguishes configured from live verified. |
| `POST /api/interests/search` | `{ "query": "Bluey", "category": "shows" }`, max 128 characters. Returns canonical records, per-provider availability and routing evidence. Never echoes the query. |
| `POST /api/interests/records` | `{ "ids": ["random public record UUID"] }`; resolves checked preview records. No client-supplied titles, URLs or verification claims accepted. |
| `POST /api/interests/recipient` | Same ID-only request. Returns **only separately approved records**. Provider matches start `unreviewed`, so current live provider results do not become public social data. |

Use `Authorization: Bearer <existing preview access secret>` and
`Content-Type: application/json`. No query strings, uploaded images, provider
login credentials, personal-location permission or profile write endpoint.
The existing AWS parallel-preview edge also requires its Basic credential and
removes that Authorization header before the origin. For that endpoint, supply
the independent interest secret as `X-Fonsters-Interest-Token` alongside the
outer Basic credential. Neither secret belongs in a released app. The two
gates are exercised together in a synthetic integration check; live AWS
verification remains pending access.
Likely contact data and precise street addresses are rejected before provider
routing. This bounded filter is not comprehensive PII detection.

Jev asks a closed-set category question at the official
[`POST https://api.typesafe.ai/v1/systemone`](https://docs.typesafe.ai/api).
Confidence below 0.75, invalid answers and failures fall back to the field's
category or general Wikipedia search. Jev never generates canonical names or
URLs and never approves content for publication. Nathan's existing key was
connected through the private local configuration on 2026-10-08. Live category
checks passed for Bluey, Taylor Swift and Disneyland; the authenticated local API
also returned real Wikipedia records through Jev routing. The key is not in Git,
the native app, or a hosted environment. Other machines/hosts need their own
secure configuration and verification.

## Provider access and reuse boundary

Reviewed against official documentation on 2026-10-08. Search engine results do
not establish provider API access, identity verification or redistribution rights.
No scraping adapter or fabricated provider result is included.

| Source | Implemented scope and remaining access |
| --- | --- |
| Wikipedia | Read-only Action API search, namespace 0, canonical numeric page IDs, disambiguation filtering. Standalone live sample lookups passed. Names/source references only; no article extracts or downloaded pictures. Records retain contributor attribution, article URL and CC BY-SA 4.0 information. Source existence does not establish factual accuracy or child suitability. |
| YouTube | Official Data API **channel** search adapter with strict safe-search, per-record source attribution, canonical channel IDs and 1-hour metadata TTL. Requires authorized `YOUTUBE_API_KEY`, product-specific review, required terms/privacy disclosures and branding before enabling. Strict safe-search is not moderation approval. Not live tested without access. |
| Apple Music | Official catalog artist search adapter using an existing `APPLE_MUSIC_DEVELOPER_TOKEN`, US storefront for this preview. No listening history, user token, playback, cross-provider playlist or subscription flow. Product/usage/branding review and token required; not live tested. |
| Apple Maps | Official public-place search adapter using an existing short-lived `APPLE_MAPS_ACCESS_TOKEN`. No device location requested or sent. Canonical source plus public-place coordinates; not a travel/status signal. Access-token renewal and approved storage/usage terms must be configured before enabling. Not live tested. |
| IMDb | **Unavailable** until licensed API/Data Exchange access and the actual product's redistribution/caching contract are established. No subscription purchased and no non-commercial bulk dataset repurposed. |
| Instagram | **Unavailable** until an approved integration is established. Business Discovery addresses supported professional-account lookup, not arbitrary account discovery; no scraping or invented universal creator search. |
| Snapchat | **Unavailable** until Public Profile/Creator Discovery partner access and actual permitted use are established. No account/OAuth credentials created. |
| Spotify | **Unavailable** pending the game/child/cross-service product policy review already recorded in the social plan. No integration or OAuth attempted. |

Sources:
[Wikimedia API licensing](https://www.mediawiki.org/wiki/API:Licensing),
[Wikimedia reuse terms](https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use),
[YouTube search](https://developers.google.com/youtube/v3/docs/search/list),
[YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies),
[Apple Music catalog search](https://developer.apple.com/documentation/applemusicapi/search-for-catalog-resources-(by-type)),
[Apple Maps server API](https://developer.apple.com/documentation/applemapsserverapi),
[IMDb licensing](https://data.imdb.com/documentation/),
[Instagram Business Discovery](https://developers.facebook.com/docs/instagram-platform/instagram-api-with-facebook-login/business-discovery/),
[Snap Public Profile API](https://developers.snap.com/marketing-api/Public-Profile-API/Introduction),
[Spotify developer policy](https://developer.spotify.com/policy).

## Caching, failure and hosting

Identical simultaneous searches coalesce into one provider fan-out. Query-cache
keys use a process-local HMAC; raw drafts are not persisted, returned, or logged.
Search cache: 5 minutes, max 512 entries. Canonical records: 1 hour, max 512,
random non-sensitive public UUIDs, optional local atomic archive with mode 0600.
No stale canonical record survives its TTL. Sources must be re-fetched to remain
available. There is no permanent account-interest store or distributed cache yet.
The current service is a tested developer backend, **not a production account API**.

Upstreams are fixed allowlisted hosts, redirects forbidden, 4-second deadlines,
responses capped at 1 MiB. Body capped at 4 KiB. The preview principal is limited
to 60 requests per minute per process. Production needs real scoped account auth,
a shared quota/budget store and durable approved-entity storage; an embedded
preview key and per-instance limits are insufficient for production.

The Vercel adapter and existing AWS Lambda adapter share the service. They are
closed by default; no new IAM permissions, secret resources or accounts are
created. Hosted activation requires secret configuration and the repository's
same-revision Vercel/AWS deployment verification. A Vercel Git status alone does
not establish AWS parity. The protected native app remains disconnected until
its separately reviewed account release; an adult UI challenge is not consent
or account authorization.

## Verification

`npm run test:interests`: authentication/CORS/bounds, coalescing/cache/TTL/disk,
no raw draft response, forged-field rejection, routing/low confidence,
multi-source attribution, outages, provider review gates, response budget and
preview quota. Provider/Jev fixture results are explicitly synthetic.
`npm run test:aws`: existing flags/preview/deployment guards remain functional.
Actual local evidence and live Wikipedia samples are in
`evidence/interest-editor/`; these generated files are gitignored.

Hosted activation is still blocked on this Air: `fishbowl-head` is not a
configured AWS profile, and the existing `default` profile returned
`InvalidClientTokenId`. The repo's pinned SST dependency is not installed.
No credential was created, account switched or dependency installed. Resolve
access to the existing Fonsters account and approve the required dependency
installation before running the dual-host release command.
