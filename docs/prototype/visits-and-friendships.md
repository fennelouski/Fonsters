# Portable visits and local friendships

The native prototype now saves and imports `.fonster.json` visit files. **Share Fonster**
opens a review sheet with chosen-feeling sharing off by default. Nathan chooses where to save
the file and whom to send it to. **Invite…** validates the selected JSON and shows a second
review before it replaces Orbit's temporary room slot. **End visit** restores Orbit without
deleting private memories or friendship records. A guest is a resolved snapshot, not a live
connection or verified identity. Recipients can keep a copy; exported files cannot be revoked.

The version 1 public document contains exactly:

| Field | Purpose |
| --- | --- |
| `format`, `version` | `fonsters-visit`, `1` |
| `publicID` | Random UUID, independent of legacy seeds and the private personality profile ID |
| `name` | Single short public display name; maximum 24 alphanumeric/hyphen characters |
| `appearance` | Resolved version 1 silhouette, palette, 32×32 raster, visible features and clipping |
| `temperament` | Public greeting warmth and play energy, both bounded 0–1 |
| `feeling` | Optional chosen label, included only when the sender checks the box |

No account identifier, email, original seed, private history, friend list, location, microphone
audio, camera frame or inferred feeling is included. Import rejects extra fields at every
level, unsupported versions, invalid palette/geometry, duplicate parts, mismatched raster
pixels and files above 128 KB. Custom names and names that collide with Coral/Moss/Iris get
the local command alias **Visitor**, included in the finite model guide. The imported source
name remains visible in the roster. A known public ID
with a changed appearance is rejected and the existing record is preserved. This detects
accidental identity changes, not hostile impersonation; offline files are unsigned.

Guests have no seed and render directly from the shared descriptor. Their original portrait
is drawn from that descriptor beside the room. Private personality learning is disabled for
guests. Their public temperament and optional feeling are read-only in the host lobby.

The host chooses one buddy and can wave, pass the ball back and forth, or sit together. Chosen
quiet/cozy/low feelings soften locomotion, idle posture and jumping, and lead nearby idle
Fonsters to keep quiet company. Feelings never come from the microphone, camera or language
model. A low feeling has no penalty, recovery requirement or forced cheering-up mechanic.

The separate `social-v1.json` archive stores public fixture identities, owner-chosen feelings,
known appearance hashes and undirected friendship counters for hellos, games and quiet moments.
These private records remain on this Mac. A deliberate pair interaction can add one shared
moment per three real seconds, including Still mode. Autonomous pair encounters can add a
moment only after forty active room seconds; background/paused/static time cannot advance
them. No absence decay is applied. Repeated taps replace the current activity and cannot create
a rapid counter burst. A relationship reads “Getting acquainted”, “Familiar faces” or “Little
friends” as a few shared moments accumulate. This is a local memory, not a global friend graph.

The two-player ball path uses one shared scene clock and a bounded parabolic arc. Greetings,
rest, roam/stop and replacement activities interrupt it. Pause, Still mode, Reduce Motion,
background and Low Power hold both creatures and the ball. Manual actions can display a
static expressive pose. No care state, public identity or friend record is removed by ending
a visit or by closing the app. Corrupt/newer archives remain untouched; that session uses
temporary memories.

## Prepared contract for future online visits

There is no online room, account service, grant or deployment in this change. The following
is the concrete boundary to implement and review before enabling a live service:

1. Authenticate the owner inside the account service. Store the mapping from private account
   ID to random public Fonster ID internally; never place private IDs or emails in links or
   visit documents. Ownership must be checked on every grant and appearance update.
2. Issue an opaque random invitation ID with at least 128 bits of entropy. A link contains
   only that revocable invitation ID. Do not reuse the public Fonster ID as a bearer capability.
   Show recipient and room scope, capabilities and expiration before the owner confirms.
3. Store a versioned visit grant with `grantID`, `ownerPublicFonsterID`, `recipientPublicRoomID`,
   `snapshotAppearanceDigest`, `scopes`, `expiresAt`, `revocationEpoch`, `status` and mutual
   acceptance. Initial scopes are `viewAppearance`, `greet`, `play` and `quietCompany`;
   `seeChosenFeeling` is optional and off by default. Require recipient acceptance; the host
   may end or block a visit. Start with a maximum 24-hour expiry rather than permanent access.
4. Each room join and event must check the authenticated issuer, exact accepted room, scopes,
   expiry, status, current revocation epoch and blocked relationships. Revoke server-side and
   disconnect promptly; queued events with the old epoch must be discarded. No client flag
   or downloaded snapshot is authority to access a remote room.
5. Publish a chosen feeling only after a separate explicit owner action and only to recipients
   with `seeChosenFeeling`. Attach a visibility scope and short expiry. Clear it when revoked
   or when the owner chooses “Just here”/stops sharing. Never infer, classify or publish mood
   from camera, microphone, typed requests or absence. Online feeling updates are distinct
   from the immutable optional label in an already-exported file.
6. A friendship needs mutual acceptance before persistent cross-account visibility. Store
   event IDs for deduplication, public participant IDs, explicitly allowed shared moments,
   revision and acceptance state. Keep private care/personality histories separate. Define
   what ending, blocking and deleting mean before sync; do not silently migrate local files
   or delete existing records. Start with bounded finite game/emote events, not arbitrary
   executable commands, location tracking or unrestricted messages.
7. Presence expires with a short lease when a device disconnects. Background/Low Power stop
   events; reconnect fetches current grant state before resuming. No unseen simulated events
   accrue while a device is offline. Observe provider cost/rate limits and build an account
   export/removal flow before releasing the service.

`appearanceIdentity` remains the resolved public descriptor and random ID. `personalityState`,
`chosenFeeling`, `friendshipState`, `roomPresence` and `visitGrant` have independent revisions
and privacy scopes. A platform-neutral sync/account SDK can adopt this contract later without
changing legacy rendering, share-link decoding or seed identity.

## Verification

`bash script/verify_social.sh` exercises twelve real resolved appearances, serialization and
privacy rejection, persisted independent IDs/feelings/friendships, corrupt-file preservation,
identity-change rejection, a foreign guest with a local name collision, read-only guest
feeling/temperament, two-player activities, 100 rapid replacements, all five motion gates,
no guest private learning and friendship persistence across ending/reinviting the same guest.
Run with Swift compiler plugins permitted on the Mac. Test archives live under
`.prototype-build/verification/` and do not use production SwiftData or iCloud.

Native demonstration flags `--social-demo --sample-visit-file PATH` create a fictional Tide
snapshot through the same validated encoding/decoding path. Add isolated `--personality-file`
and `--social-file` paths, then `--lobby`, `--scene-export-dir PATH` and
`--window-export-file PATH` to verify the shared game and actual layout. Scene exports are
RealityKit renders of the running app's entities. AppKit layout captures omit Metal content;
they are not full desktop screenshots. The new Save/Invite panels, keyboard tab flow and
VoiceOver need a human UI pass because desktop-control tooling is currently unavailable.
