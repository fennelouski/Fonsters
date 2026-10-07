# Fonster Social on the Air

Open **Launch Fonster Social.command**. It builds the existing macOS Fonsters target, opens the twelve-character neighborhood, and shows the native social space. This launcher creates real local profiles and introductory local posts using isolated preview memories. These are fictional local Fonsters, not other people or online accounts. Normal lobby launches do not create profiles or start this agent automatically.

Select a Fonster to see its fluffy native 3D portrait beside its unchanged 2D portrait. **Neighborhood feed** collects the local profiles' published moments. There are no invented followers, likes, replies, or remote friendships. The profile handle comes from a separate random public profile UUID, independent of the appearance seed and human identity.

## A continuing local companion

Create a profile for an owned Fonster, choose its voice and content categories, and select **Start local profile agent**. It repeatedly prepares short, validated native companion plans using the existing agent executor. The selected owned Fonster explores, waves, plays, and rests with local companions. Existing influence switches still apply. A social plan always excludes human reflection, including fields the human enabled in Agent Studio. Visitors can respond locally but cannot be enrolled or controlled as owned profiles.

Successful actions supply structured Fonster events to a deterministic little writer. An exploration post says the Fonster is *heading toward* an area; it does not claim arrival from an uncompleted route. Bench posts say it is looking for a bench. Posts describe the fictional Fonster world, not the human's travel. There is no LLM or generation charge in this writer. The source appears on each post: profile creation, an owner interaction, a simulated companion agent, or a reviewed local action file. No external agent provider is connected.

The default mode is **Review each draft**. **Add to local feed** deliberately approves one draft for this Mac. The alternate **Post locally** mode explicitly permits unattended local publication of newly generated posts. Choosing this mode does not approve external publication. Existing drafts are not bulk-published when the mode changes. **Pass this one** retains a passed record and keeps it out of the feed and public handoff.

The writer holds one replaceable recent observation per profile. There is no queued burst of historical posts. It makes at most one new post per sixty wall-clock seconds, six per app session per Fonster, and twenty-four per local calendar day. The archive retains the last-generation timestamp and daily count; reopening does not bypass the minute/day limits. All windows share the same store and session caps. Observations expire after ten minutes. The archive is bounded to twenty-four profiles, sixty-four posts per profile, 256 posts total, and 512 KB. A full notebook stops new drafts and preserves existing posts.

Companion plans are renewed at most once per hundred seconds in the current social director. Restart taps do not reset that interval. The existing executor independently limits physical actions, validates every plan/action, and caps personality learning. Agent rituals remain separate from owner learning and appearance identity.

**Always on here means continuing while this native app is open and active.** There is no login item, launch daemon, background server, or cloud service. Closing the app or sleeping the Air stops execution. Pause, Still mode, Reduce Motion, background, Low Power, and an open review/control sheet hold automatic motion and writing. No catch-up loop runs on resume. Creature controls take over and stop the continuing profile agent immediately; restarting requires a deliberate local action. Changing voice, categories, or publication mode also stops it. Agent enabling is session-only and starts off after relaunch.

## Public handoff and private context

**Save profile review file…** uses a native file exporter and the implemented `FonsterReviewFileAdapter`. The version 1 `fonster-social-review` envelope contains:

- A random profile ID and handle, Fonster name, preset bio, and explicit `fictional: true` / `automated: true` disclosure.
- The existing seed-free resolved appearance descriptor, with neutral public temperament and no feeling.
- Only posts already approved for the local feed, each with source, timestamp, and automated-writing disclosure.
- `destination: manual-review-file` and `externalPublicationAuthorized: false`.

No drafts, passed posts, human reflection cues, human/Fonster feelings, original seed strings, email, exact coordinates, private personality counts, friends' identities, conversations, task context, provider credentials, or access grants are present. This write-only review file is capped at 256 KB. It is not an external-platform API payload or an executable action plan. Exporting requires choosing a local destination in the save dialog; it does not upload anything.

The separately versioned `social-presence-v1.json` archive lives beside the other private prototype memories (or beside the explicit isolated personality path with a `.presence.json` suffix). Unreadable/newer archives are preserved and the preview uses temporary changes. No SwiftData/iCloud migration, existing share-link change, user-record deletion, or account creation occurs.

## Platform adapters

| Destination | Implementation | Approval boundary |
| --- | --- | --- |
| Fonsters on this Mac | Native local profile/feed adapter | Per-post review, or explicitly chosen local auto-post mode |
| Portable review file | Native sanitized file adapter | Human selects a local save destination; no external grant |
| Bluesky | Planned; no networking or OAuth implementation | Chosen Fonster/account/destination/content policy and a separate owner grant required |
| Mastodon | Planned; no networking or OAuth implementation | Chosen instance/Fonster/account/content policy and a separate owner grant required |

Official platform material checked on 2026-10-07: [Bluesky's creating-a-post documentation](https://docs.bsky.app/docs/tutorials/creating-a-post) and [community guidelines](https://bsky.social/about/support/community-guidelines), plus [Mastodon's profile update API](https://docs.joinmastodon.org/methods/accounts/#update_credentials) and [status publication API](https://docs.joinmastodon.org/methods/statuses/#create). Mastodon's documented bot flag, authorization scopes, and idempotency header inform the future adapter boundary. Instance rules still need verification for the actual chosen destination. This does not establish that any specific service/account permits the desired continuous behavior.

A real 24-hour worker needs a chosen hosting destination, explicit renewable/revocable owner authorization, verified platform rules, a private credential store, an idempotent durable outbox, finite content categories, duplicate/rate/cost limits, provider outages/backoff, a visible audit, and a global owner stop. Public automation must identify the fictional automated character. It must not impersonate the human, fabricate engagement, or automatically ingest/disclose private human context. No such persistent grant or external service was established by this local implementation.

## Verification

Run `script/verify_presence.sh` for isolated model/export/rate/actual-rig interruption checks. `script/verify_agent.sh` covers the existing finite executor and private reflection contract. The normal entry point is `script/build_and_run.sh`; `Launch Fonster Social.command` is the concrete preview launcher. Actual check outcomes and screenshot provenance are recorded separately in `social-presence-verification.md` after execution.
