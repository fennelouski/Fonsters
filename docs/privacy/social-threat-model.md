# Future social Fonsters: privacy and abuse review

8 October 2026 · planning only · no live social or provider service enabled

This review accompanies the [product/backend plan](../product/social-fonsters-plan.md).
It does not change protected play's current data practices or authorize accounts,
uploads, location, streaming-provider OAuth, credentials or infrastructure.

## Content and trust boundary

Future social communication is nonverbal and catalog-based. A server-validated
projection can contain random public creature IDs, approved emotion/activity/icon/
sound/voice/keepsake IDs, quantized bounded parameters, grants and expiry. Only
approved selected activities (ball play, walking, sitting, climbing, swimming and
running) are exchanged. Rendering uses the vetted asset catalog and approved
appearance representation; no arbitrary custom texture, file, image, URL or script
is accepted in an action/asset field.

Personal names, bios, diary entries, preference text, appearance seed text, email,
CloudKit identifiers, location/routes, raw camera cues, recordings and recognized
words stay outside social payloads, scenes, visits and memorabilia. Memorabilia
have no inscriptions or custom artwork. Settings/consent/reporting/accessibility
copy is a separate necessary interface, not a way to display excluded profile
content. AI/agent suggestions map to the same finite schema; an external agent
cannot add vocabulary or bypass owner approval, Stop, grants or eligibility.

The sole proposed social text exception is existing music track/album/provider
metadata requested from a listening icon, and only after provider terms/license
approval. Generic music activity needs no provider integration. Future permitted
metadata uses validated provider IDs, authorized artwork/links and the viewer's
chosen playback service and action. No music stream or user audio is exchanged.
Record-to-creature-sound is unresolved: private/local input may select a vetted
preset and bounded parameters, never transmit user-generated audio bytes.

Private accounts and social data need separate server authorization; iCloud login
or possession of a legacy share link is not authorization. Missing/declined/expired
eligibility stays protected. Every friend/status/visit/asset/music delivery checks
owner, viewer, audience, peer restrictions, active grant and block state at send
and receive, including queues and caches. Clients cannot choose their own age
eligibility, public ownership or locked core appearance.

## Risks and required controls

| Risk | Required design and verification before release |
| --- | --- |
| Text/media leakage | Separate allowlisted social schema, rejection of unknown fields and IDs, canonical parsing and bounded values. Fixtures must prove that current name/bio/favorites/seed/diary/audio never appear in social payloads, rendered bubbles, accessibility labels or asset metadata. |
| Covert messages or identifying patterns | Quantize expressive timing/energy, restrict sequence length and combinations, apply cooldowns/per-pair/global caps and review catalog semantics. Finite vocabulary reduces bandwidth but cannot guarantee that people never encode meaning or identity in patterns. |
| Spam, pursuit or targeting | Two-sided friendship and visit controls, capped invitations/actions/gifts, quiet-hours/expiry, owner Stop, block/report and rate-limited agent grants. No initial minor stranger discovery or age-based client self-assertion. |
| Distressing or abusive combinations | Vetted behavior/sound combinations, loudness/duration caps, mute/Reduce Motion/static options, user-selected emotional status and recipient controls. Do not infer or diagnose a human's feelings or expose private diary-derived labels automatically. |
| Blocking bypass | Central server enforcement on discovery/location/status/visits/gifts/music/recontact, queued job cancellation, cache/subscription invalidation and tests across reconnect/offline/alternate client paths. Account re-creation abuse needs a reviewed privacy-preserving anti-abuse design. |
| Misleading social autonomy | Visually distinguish asynchronous avatar activity from a human's live response/consent; disclose actor provenance in necessary controls. Owner and recipient may interrupt; expired grants never resume automatically. |
| NPC impersonation or pressure | Consistent built-in marker and clear onboarding/accessibility explanation; no GPS proximity, human online presence, sentience or fabricated popularity claims. Use public creative themes only, keep encounter history private and distinct from versioned definitions, and confirm only mechanically granted collectibles. No absence guilt or pressure. |
| Sensitive routines and locations | Location/calendar/Watch/health remain off until separately reviewed. Manual activity works without permissions. No precise home/school routes, event text, health data or attendance inference in social status. Nearby discovery and collectibles need their own exposure assessment. |
| Music terms and explicit metadata | No integration until actual permitted provider scope is established. Review track titles/artwork and explicit-content flags, region/catalog availability, attribution and authorized playback links. Do not treat an API or subscription as permission for cross-service social status. |
| Malicious external assets/URLs | Catalog manifests include reviewed original/license provenance, immutable hashes and versions; reject custom uploads, scripts and arbitrary URLs. Any permitted provider link is resolved from a validated ID and allowlist, not supplied by a peer. |
| Reports and moderation privacy | Keep minimal event IDs/catalog IDs/timestamps and necessary restricted evidence, not default journal/audio capture. Publish retention/legal basis and access controls; make report/block/contact available before UGC release. Review symbols, patterns and music metadata as potential abuse evidence. |
| Deletion/withdrawal gaps | Revoke grants/tokens, cancel queued visits/agents, invalidate invitations/caches and replay tombstones after backup restore. Remove identifying origin links from any permitted generic keepsake; no personalized text/art keepsake is accepted. Document recipient-copy limits. |

## Discreet blocking and unblocking

Blocking is discreet by default: no notification or explicit blocked message to
the other person. The server prevents access and recontact immediately, including
previously queued interactions. The blocked user's client must not receive false
delivery confirmation; unavailable/pending/failure feedback can avoid disclosing
the reason without pretending a gift or visit succeeded. A person may infer a
block, so no promise of undetectability is made.

Unblocking is explicit and reversible. It does not replay blocked messages/gifts/
visits, restore location/status/music grants or automatically re-establish a
friendship. Mute affects the local presentation only and must not be labeled as
server blocking. Any proposed hidden/mute variant needs truthful distinct semantics.

## Current local export conflict

The current private library allows names, stories and favorites. Parent-directed
`.fonstervisit` exports include a name and optionally backstory/preferences/feeling.
Legacy base64 portrait links expose original seed text. These are preserved local
formats and do not meet the future social communication schema. No export endpoint
or background uploader may reuse them as social events. Add a new versioned
projection with explicit tests before social transmission; preserve private
records and frozen link decoding without silent migration or record deletion.

## Unresolved release decisions

Country/audience/service classification, age assurance, consent and parental
revocation, first account cohorts, backend/operator/moderation ownership, private
diary keys/sync, retention/backup policy, blocking abuse controls, catalog vetting
and any provider license are unresolved. No country or provider is cleared by
this document. The current child policy's operator contacts and matching public
website publication also remain unfinished release work.

Provider constraints checked against [Spotify's Developer Policy](https://developer.spotify.com/policy)
(including games/children/cross-service/metadata restrictions) and
[Apple's Developer Program License Agreement, MusicKit section](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)
(album art/text tied to playback or playlist management). These constraints may
make the proposed cross-service status unsuitable without a different licensed
design. Other primary release sources are linked from the product plan and
[protected play release boundary](release-boundary.md).
