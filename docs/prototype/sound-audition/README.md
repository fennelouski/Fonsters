# Fonsters sound batch workflow

This is a working offline/dry-run tool. No ElevenLabs generation request or credit-consuming
download has been made. The native app currently uses its 15 original synthesized chirps.

Run with the already-installed Python:

```sh
python3 script/sound_pipeline.py generate --event greet
python3 script/sound_pipeline.py generate
python3 script/verify_sound_pipeline.py
```

The greeting pilot is four one-second clips, one per timbre family, estimated at **160 credits**.
The complete prepared list is 24 clips estimated at **960 credits**. Dry runs do not read
credentials, initialize HTTP or write a generation ledger. Only authored imaginary-creature
prompts are sent in an approved future run. Microphone audio, camera frames, legacy seeds,
emails and personality histories are never request inputs.

## Secure runtime and approvals

Read-only metadata on 2026-10-07 confirmed `ELEVENLABS_API_KEY`, encrypted, in **Production**
on the existing `picturegrid-tts-backend` Vercel project. The Air's PictureGrid source uses
`process.env.ELEVENLABS_API_KEY` in `api/_lib/elevenlabs.js` for `/v1/text-to-speech/`.
This establishes location and existing use; it does not establish sound-effects key scope,
available credits or the account's commercial plan. No secret value was retrieved, decrypted,
printed, pulled into a local env file or copied to Fonsters.

The connector's environment-list action returned 403. The installed Vercel CLI's metadata-only
`env ls production` succeeded using its existing session. That CLI also reported automatically
updating its existing official Vercel Claude plugin. No backend code or environment was changed.

Keep the key in the already-approved server runtime. A future bounded job can run this tool
there and return reviewed audio files to Fonsters. Before doing that, Nathan needs to approve:

1. Reuse of that account/key for Fonsters sound effects, with its existing scope verified by
   the account owner. Any new credential, broader scope or permanent cross-project access needs
   a separate secure user handoff/approval.
2. The account's paid commercial-use plan and a credit cap, for example the **160-credit pilot**.
3. The concrete server job/runtime wiring. No new endpoint, deployment, permission or persistent
   credential setup has been made by this task.

Never send the key in chat, a URL or a CLI argument. Never bundle it into the Apple app.
ElevenLabs [API-key guidance](https://elevenlabs.io/docs/overview/administration/workspaces/api-keys)
supports sound-effects scope restrictions and per-key credit quotas. An account-side quota is
the provider-enforced hard ceiling; changing it requires the owner's approval. Our local ledger
is a conservative estimate reservation, **not a guarantee about provider billing**.

After those approvals, the operator can run the bounded pilot in its approved runtime:

```sh
python3 script/sound_pipeline.py generate --event greet --execute \
  --approved-credits 160 --commercial-paid-plan ACCOUNT_PLAN \
  --output APPROVED_PERSISTENT_BATCH_FOLDER
```

`ACCOUNT_PLAN` is the non-secret plan name confirmed by the operator. The runtime supplies its
existing `ELEVENLABS_API_KEY`; this command does not configure or save a credential. The output
must persist across invocations; an ephemeral Vercel function filesystem is unsuitable for
resumable billing records. An approved job with durable storage/runtime wiring remains to be
chosen. The script requires Python; if that approved server lacks it, port the runner or use an
existing suitable job runtime before execution. Do not install a runtime without approval.

## Generation, failures and provenance

The tool calls the official `/v1/sound-generation` endpoint with `eleven_text_to_sound_v2`,
fixed duration and `mp3_44100_128`. Requests are sequential. An exclusive file lock protects
one batch, the full pending estimate must fit the approved cap before the first call, and
each reservation is atomically persisted **before** calling the provider. Resuming skips all
previously attempted asset IDs. Prompt changes require a new ID. No automatic retries occur
for HTTP failures, timeouts, uncertain outcomes or failed saves; reservations remain held.
Inspect provider usage before deciding whether a replacement is safe. Unexpected higher
reported charges stop and hold the entire batch, including later resume attempts.

The ledger records prompt/model, timbre/event tags, generation time, raw asset SHA-256,
operator-confirmed plan, dated license-source reference, estimated reservation and the
optional response `character-cost` header. When that header is absent, cost remains unknown
and requires reconciliation against the provider. This metadata is an audit reference,
not an independent legal determination or a complete archived license agreement.

[Fixed-duration pricing](https://elevenlabs.io/docs/overview/capabilities/sound-effects) is
documented at 40 credits/second. [The API schema](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert)
and [commercial-use FAQ](https://elevenlabs.io/sound-effects) were checked on 2026-10-07.
Commercial use requires a paid account under that FAQ; dollar cost depends on the account's
plan, included balance and any overage terms. The tool does not purchase credits or upgrade plans.

## Offline curation and playback palettes

After approved generation, run on the Air using its existing audio tools:

```sh
python3 script/sound_pipeline.py curate --output APPROVED_PERSISTENT_BATCH_FOLDER
```

Raw MP3s are preserved. Curation first tries `/usr/bin/afconvert`, with the already-installed
`ffmpeg` as a fallback. The local offline MP3 fixture exposed an `afconvert` format error on
this Air; the fallback passes. No new software was installed. The ledger records which decoder
was used. If neither works, the clip is quarantined. Curation verifies hashes, decodes to 22,050 Hz mono signed
16-bit PCM, checks duration/silence/clipping, applies a capped RMS gain toward -24 dBFS with
a -6 dBFS peak ceiling and 10 ms endpoint fades, and emits separate normalized WAVs. It
quarantines failures without regeneration. This is RMS normalization, not LUFS mastering.
Speech/music, harshness, character fit and subjective loudness need a human audition.
Every generated and normalized asset starts with `audition_approved: false`; no output is
automatically copied into the app or treated as production-ready.

`palettes.json` maps the twelve public fixture names to four curated voice families. The
tested `PaletteSelector` chooses only approved family/event matches, applies a 1.2 second
per-character cooldown and avoids the last two clips when the pool permits. An exhausted
single-clip pool stays silent. The current app's favorite Warm/Clear/Bright chirp preference
is a local placeholder; importing an approved ElevenLabs pack and mapping that preference
to richer voice variants remains future integration work.

Offline tests use an injected fake transport and fake credential. They cover zero-call dry
runs, preflight caps, resume, request hashes, charge accounting, timeout/HTTP failure holds,
unexpected-charge holds, PCM quality, offline MP3 decode/curation and tagged palette repeat avoidance. Actual provider
authentication, generation, MP3 decode of an actual ElevenLabs response, license evidence from Nathan's account
and subjective audition remain untested.
