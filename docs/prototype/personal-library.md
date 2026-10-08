# Personal Fonster library

The full-window lobby now uses saved Fonsters. An empty library gets four
account-specific starters; the plus creates another original fuzzy friend.
Both starters and custom Fonsters can be named, given a backstory, and shared.
Existing saved creatures retain their seeds, names and history.

## Account consistency

`PersonalFonsterLibrary` reads the existing CloudKit container's account status
and user record ID. A namespaced SHA-256 digest is used privately to select four
original appearances and initial names. The raw CloudKit ID and email are not
saved, logged or exported. The same account/container gets the same starter
appearance seeds and logical IDs on each device. Different accounts get different
sets. Without iCloud, a random persistent local token selects a local set.

A transient account or network failure does not create another random starter
set. The lobby's help panel offers Retry, and custom creation remains available.
Existing nonempty libraries are not automatically reseeded. SwiftData continues
to use its existing synced/local configurations; this change does not move data
between them, change entitlements, or delete records.

SwiftData/CloudKit cannot enforce a unique model constraint. Two devices that
first launch before their initial sync may each insert the same logical starters.
The lobby groups those starter records by their private starter key, displaying
the most recently edited profile (or newest original record) once. Ties are
resolved by stable saved content. All rows remain in the store, including their
history; custom Fonsters are never grouped by name or appearance.

Names and optional biography data live on the existing `Fonster` model, so they
use the existing iCloud sync path. Added attributes are optional, with no unique
constraints or new relationships. Learned touch/care memories remain in their
existing separate local archive. No favorites, feelings, or biography are
inferred from a person, microphone, camera or account identity.

Apple documents the existing asynchronous sync and schema restrictions in
[Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).
Live two-device iCloud replication requires verification with signed-in devices.
Before an App Store release, the additive CloudKit schema needs the normal
development-schema review and production promotion. This native local update
does not promote a production schema or create/change accounts.

## Creation and profiles

- Plus opens a living 3D draft with eight original appearance portraits. Dice
  finds eight more. Choosing a portrait previews it without saving a record.
- Name is limited to 32 characters. A saved Fonster's appearance is unchanged
  when naming or editing its story.
- Book opens backstory (600 characters); heart opens likes and dislikes; screen
  opens movies and shows; star opens creators and celebrities. Each list supports
  up to eight 64-character entries, separated by commas or newlines.
- Checkmark saves explicitly; X dismisses the draft. The curved arrow resets
  unsaved name and profile edits. Creation cancellation leaves no record.
- Saving a new friend centers it in care. Saving an edited name retains the
  selected friend and its learned care identity. Name and backstory edits keep
  the native stage, camera, rigs, positions and walking routes intact.
- Panels and icon buttons retain hover help, accessible names and help guides.
  Draft animation honors Reduce Motion, backgrounding and Low Power Mode.
- Unsupported legacy appearance families retain their exact 2D portrait in the
  profile editor. The original gallery still edits appearance and exports PNG/GIF.

## Sharing

Both starter and custom Fonsters use the same portable visit flow. Backstory and
favorites are off by default in the share sheet. Turning them on previews their
public contents before opening the system share UI. Email-like strings are
omitted from this public copy; the private saved biography remains unchanged.

Visits without biography retain the original version 1 format. An explicitly
included biography uses version 2, with bounded, allowlisted fields. The updated
reader accepts versions 1 and 2 and rejects hidden metadata. Original base64
seed links are unchanged. Public visits still contain a random public ID and
resolved appearance, never the account token, private model ID, original seed or
learned memory archive. Older preview builds only accept version 1 visits.

## Local preview and verification

`./script/build_and_run.sh --verify` builds and opens the task-local Mac preview.
Its own SQLite library is `.prototype-build/personal-library/store.sqlite`, with
CloudKit disabled. Scripted legacy demonstrations remain isolated in memory.
`--library-store <path>` selects an explicit separate test store.

`./script/verify_personal_library.sh` checks synthetic same/different account
selection, setup idempotency, duplicate convergence without deletion, custom
creation, profile bounds, v1/v2 visit compatibility and public-data privacy.
Apple TV's world reads the same saved library; watch/older gallery first-launch
paths use the same account-specific starter helper. Profile creation/editing
is available in the full-window Mac/iPhone lobby.

The verification script also writes a synthetic SQLite store using the exact pre-feature model from
`e550dda` in a separate executable, then opens it with the new model to verify
the real additive store upgrade and original seed/history preservation.

`PersonalFonsterLibraryTests` exercises native iPhone creation, all profile
fields, Cancel, optional sharing, rename, retained starters and persistence
after terminating/relaunching the app. `ContinuousLobbyTests` retains search,
care, repeated touch/reactions, camera, Undo, Reduce Motion and old link checks.

Actual logs, screenshots and result bundles remain local under
`evidence/soft-world/personal-*`. Live cross-device iCloud delivery, production
schema promotion, real VoiceOver traversal and physical keyboard input are not
proved by these synthetic/simulator checks. Physical iPhone launch depends on
the device being unlocked; report its actual result in the local release receipt.
