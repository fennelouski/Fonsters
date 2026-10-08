# Fonsters protected play privacy policy

Draft for the protected native app · version 1 · 8 October 2026

**Public release status:** operator contact fields below need confirmation. This
document is implemented in the native app's Privacy & family sheet. It has not
replaced the policy on nathanfennel.com or been submitted to App Store Connect.

## Who this experience is for

Fonsters protected play is a small world for children and families to explore,
dance, play and care for fuzzy creatures. Everyone currently receives this
experience. No Fonsters signup is required. We do not request or retain age,
birthdate, country, location, email, telephone number or contacts to start playing.

There are no advertisements, analytics SDKs, tracking, purchases, public profiles,
public feeds, direct messages, stranger matchmaking or external agent control in
this experience. Companions in the lobby are local creatures or manually imported
snapshots; they are not connected strangers. A future account experience will
require a separate age, region and consent review and a separate notice. Protected
play will not silently become an account or social service.

## What Fonsters processes and where it goes

| Information | Purpose and destination | Retention and control |
| --- | --- | --- |
| Appearance seed, name, creation date, internal library ID, optional fictional story, private favorite drafts and selected source references | Creates and saves the creature. SwiftData stores these on the device. The existing iCloud configuration can sync them through Apple's private CloudKit database when the user's iCloud setup permits it. Typed favorite drafts match only a small bundled source catalog; the protected app does not submit them to an external search or Jev service. | Kept until edited or removed. Existing records are not deleted or migrated by this update. Use made-up names/stories and avoid contact details. |
| Namespaced account digest used for matching starter creatures | Makes starter appearances consistent with the existing iCloud account. Apple's account record identifier is resolved internally and hashed; the raw identifier is not logged, stored in the appearance descriptor or exported. | Private library seed/starter identifiers remain part of the library. They are not public sharing identifiers. |
| Local care tendencies, chosen feelings, friendships, movement memory and sound preference | Supports non-punitive play and familiar reactions. Kept in local app files, separately from appearance identity. | No absence penalty, death or care deadline. Learned movement can be discarded before Keep, then undone or reset. Care files are not currently synchronized across accounts/devices. |
| Camera frames and transient face/body measurements | Optional on-device mirroring of eyes, mouth shape, head, hands and movement with Apple Vision. Approximate screen-facing attention can trigger a brief greeting; it does not identify the user or infer their feelings. | Off initially. Enable requires a grown-up task and OS permission. Frames and measurements are not archived or uploaded by Fonsters. The owner's chosen feeling is never changed by camera cues. Capture pauses in the background/low power; Stop, switching creatures or leaving care turns it off. |
| Microphone audio and recognized words | Optional on-device English action recognition with Apple's Speech framework. No cloud recognition fallback. | Off initially. A grown-up task and OS permissions are required; unavailable local speech support leaves icons/typing usable. No recordings or transcripts are retained/uploaded by Fonsters. |
| Three bounded movement values | Keeps a practiced wave/sway/rhythm after explicit Keep. | Tempo, amplitude and wave strength only. No voice clone, facial template or saved video. Discard, Undo and Reset are available. |
| Short typed action requests | Local known-command parsing; optional compatible Apple on-device Foundation Model classifies a physical action. | No external AI service, conversational response, prompt history or transcript upload/storage by Fonsters. |
| Local preferences | Onboarding, fonts, feature overrides and protected play settings use app/app-group UserDefaults. | No advertising identifier or cross-service tracking. |

Fonsters does not run third-party random-text or feature-flag requests in protected
play. Random text comes from bundled local providers. The developer operates no
account service or analytics endpoint for this experience. Apple processes iCloud,
backup, app distribution and optional device diagnostic information under the
family's Apple settings and Apple's policies; these are not public Fonsters posts.

## Parent-directed sharing

Sharing, original portrait exports and Messages stickers are behind a grown-up
task. The task helps prevent accidental access; it **does not verify age or
constitute legally verifiable parental consent**. It cannot enable accounts,
external agents or public social posting.

A 3D visit file contains a random non-sensitive public identifier, creature name,
resolved appearance and limited personality tendencies. Chosen feeling and
selected bundled source references are optional and initially excluded. New
visits never include typed favorite drafts or backstory. Source identification
does not establish endorsement or child suitability. The recipient view hides
raw text from older imported visits too; previously sent copies remain with
their recipients. It contains no original seed, CloudKit account
identifier, private care key, recordings or conversation history. A recipient
can keep or reshare a copy; sending cannot be undone by Fonsters.

The editor camera is separately off initially and requires the same grown-up
task and OS permission. Closing the editor or changing the preview appearance
stops its capture. Opening a source link is a parent-directed action in the
system browser; the destination has its own privacy practices. No draft text
is appended to that link.

The original 2D link format is preserved for compatibility. Its base64 JSON
**contains recoverable original seed text**. Base64 is not encryption. A parent
must review any personally identifying seed text before sharing a legacy link.
The original PNG/GIF/JPEG exports may also reveal the chosen filename or metadata
to the recipient. The parent's chosen operating-system share destination controls
delivery. Recipients and external destinations have their own practices.

## Choices, access and removal

Read this notice through the hand icon in the lobby or care screen without a
grown-up task. Disable camera/microphone with their buttons or Stop; system
permissions can also be managed through device Settings. Discard a practice draft
before Keep, or undo/reset movement memory. A parent can inspect/edit/remove
library entries in the original gallery and manage private iCloud/backup data in
Apple settings. App deletion alone does not necessarily remove backups, iCloud
copies or snapshots someone else received. This update performs no user-record
deletion. For help with access/removal questions, contact the operator below.

## Operator and privacy contact — complete before publication

Operator: **Nathan Fennel** (confirm public legal/operator name).

- Mailing address: **[owner confirmation required]**
- Privacy email: **[owner confirmation required]**
- Telephone: **[owner confirmation required]**
- Existing support site: nathanfennel.com

Do not publish the placeholder contact fields. Do not send a child's private
appearance seed, recording or story when asking for help unless necessary and
explicitly requested through a reviewed support process.

## Changes

Protected play's data practices are versioned separately from any future account
experience. Adding collection, public communication, location/reflection services
or external agent access requires a new review and the notices/consent required
for the relevant audience and countries before the feature is enabled.
