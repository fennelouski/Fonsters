# Audio-worker handoff

Prepare original, soft sounds that make fuzzy Fonsters feel alive. This folder is
an authored production catalogue, not generated audio or an API request ledger.
**83 cues, 433 requested clips: P0 15, P1 212, P2 206.** No API was called, no key
was read, and no credits or spending are authorized by this catalogue.

Start with [first-batch.csv](first-batch.csv): the 15 exact replacement filenames
already understood by `CreatureSoundBank`. Deliver them for audition before
expanding. Treat the remaining 418 clips as a menu, not an instruction to generate
all at once. Agree the batch and credit cap with the owner in your generation task.

## Files to use

| File | Purpose |
| --- | --- |
| [catalogue.json](catalogue.json) | Versioned source of truth: cues, full prompts, delivery specifications, voice/take identity and future playback hints |
| [first-batch.csv](first-batch.csv) | First 15 clips; drop-in filenames after review |
| [production-queue.csv](production-queue.csv) | All 433 assets, spreadsheet-ready, one complete prompt per row |
| [cue-index.md](cue-index.md) | Human-readable cue/trigger/priority overview |
| [review-sheet.csv](review-sheet.csv) | Pending technical, listening and licensing review for each asset |
| [provenance-template.json](provenance-template.json) | Delivery record example; fill with actual measurements/evidence |

IDs are stable authored public labels, never derived from a user's seed, account,
email, location, microphone recording or personality history. `voice` describes
sound, independently of appearance family; a flower and a galaxy can share a
voice. Do not upload any private app data to personalize a prompt.

## Generate in this order

1. **P0 — 15 clips.** Three voices × five currently loaded events. Keep names
   `fonster_greet_0.wav` … `fonster_look_2.wav` exactly. `_0`, `_1`, `_2` are voice
   indexes (Warm, Clear, Bright), **not take numbers**. Generate alternatives only
   within a separately agreed audition batch; publish one winner per filename.
2. **P1 — choose a small approved subset.** Responsive touch, gestures, wake/sleep,
   greetings, launch lettering, basic UI and waypoint feedback. Each future voiced
   cue requests three takes for each of the three voices. These are **not wired**.
3. **P2 — after listening and integration.** More casual expressions, friendships,
   footsteps, environments, weather ambience, dance grooves and extra UI accents.
   Do not fill the bundle with hundreds of unreviewed files.

Warm is round, velvety and breathy; Clear is a small rounded reed-like chirrup;
Bright is softly bubbly and playful. Articulation and rhythm must distinguish
voices/takes, not just pitch-shifting the same source. No words or identifiable
human voices, screams, punitive crying, alarm tones or borrowed melodies. Sadness
is a quiet tender sigh; it does not communicate neglect or threaten the owner.

For thousands of future sounds, expand approved voice/take libraries gradually:
keep cue IDs stable, add approved voice IDs and separate takes, and retain a small
curated playback pool per creature. This catalogue makes no request for thousands
of billable generations. Existing personal-bank recipes already offer an
independent expansion route; do not regenerate them blindly.

## Delivery and editing

Deliver into `.prototype-build/audio-delivery/<batch-id>/` (already ignored), with
`wav/`, a completed provenance JSON, review sheet and audition notes. Do **not**
overwrite bundled placeholders or `sound-manifest.json` directly. A later app
integration imports approved files and updates the runtime manifest/hashes.

Required shipped candidate format: **dry mono PCM WAV, 44,100 Hz, 16-bit**. Retain
higher-quality original masters separately if available. No baked room reverb or
panning; the app owns spatial placement. Sample peak ≤ −3 dBFS, no clipping or DC
clicks. Aim near −22 LUFS integrated for clips at least three seconds long; short
chirps are compared by ear/peak against the bank, not forced to a misleading LUFS
target. Record measured peak/loudness (or null with a reason if unavailable).

One-shots: ≤20 ms initial silence; clean natural tail, normally 3–12 ms boundary
fades. Duration ranges describe the **edited delivery**, not provider constraints.
For a subsecond chirp, generate an allowed-length isolated source then trim/edit
without cutting the attack or tail. Do not pad every short cue to a second.

Loops: no baked fade, intro, outro or final cadence. Record loop points in frames;
listen to at least ten repetitions for seam clicks or conspicuous recurring
foreground events. Atmosphere must stay quiet and unobtrusive. Six dance loops
are original four-bar 4/4 grooves: two each at 75, 95 and 115 BPM. Exact duration
is `960 / BPM` seconds (round to the nearest sample); queue rows include the
intended duration. Do not stretch them to an arbitrary integer duration. No artist
imitation, copyrighted song references or spoken/sung vocals.

An audio worker using ElevenLabs should reuse only its separately authorized
runtime/account and current provider parameters. Verify supported durations,
model/output encoding, license and the approved credit cap in that worker's run.
The queue is provider-neutral: **do not POST a CSV row or catalogue object to an
API**. Never put credentials in this repo, command arguments or provenance.
Preserve ambiguous generation holds instead of blindly retrying paid requests.

## Playback and integration contract

Current implementation: `CreatureSoundBank` loads only WAVs named
`fonster_<event>_<voice-index>.wav`, has one replaceable player per controller,
uses gain 0.55 and does not support a take library or ambient loops. Ordinary
non-core actions may alias to play/rest today. `current_bank` refers to this
loader contract, not proof that generated audio has been delivered or approved.
All other catalogue entries are `requires_wiring`; future hints are requirements
for the integration worker, not assertions about current behavior.

- Opt-in sound; keep visible actions and accessible status. Never use audio alone
  to indicate consent, error, ownership, success or a changed feeling.
- Stop on sound-off, pause, background and low-power suspension. Suppress output
  during microphone listening and practice capture, including **voice audition**;
  review all playback entry points because the current audition path lacks the
  ordinary action's listening check. Do not request microphone permission for SFX.
- Static/Reduce Motion modes must not create automatic movement-driven sound.
  Explicit owner actions follow the existing controller behavior; no hidden timers.
- Touch cues come from debounced reaction transitions, not every drag sample.
  Use intensity/speed/location to select a reaction/take, never to exceed the mix
  ceiling. Discard stale queued reactions; fade/replace instead of building a queue.
- Eye/head/body tracking updates do not each emit sound. Idle blink is silent;
  the P0 blink is for an explicit action. Mirror gestures need confidence, temporal
  stability and cooldown. Chosen emotions may select cues; camera measurements
  do not establish the human's emotion.
- Future scene mix: one foreground creature vocal at a time, one quiet ambience
  layer, optional dance loop; duck ambience under actions. A many-creature lobby
  needs a scene-level cap because separate current controllers each own a player.
  Avoid retriggering footsteps/chatter for every distant creature. No hover,
  tooltip, every-keystroke or unsolicited notification sounds.
- Catalogue cooldowns are minimum proposed constraints; global caps and explicit
  mute/lifecycle gates take precedence. Suspend loops without auto-restart storms.
- Weather ambience is artistic scenery, never a forecast alert or a safety warning.
  Apple's data attribution is handled by the weather UI, not an audio watermark.

## Accept a batch only after review

Check exact IDs/filenames, distinct waveform hashes, WAV channels/rate/bit depth,
duration, peaks, leading silence, complete tails and repeated loop seams. Listen
quietly on Air speakers and headphones; assess warmth, syllable-free character,
non-startling transitions, voice consistency and repetition fatigue. Never change
system volume automatically. Record untested device routes explicitly.

Retain provider/model, generation date, hash of the exact submitted prompt,
original file hash, edited WAV hash, editing notes, actual cost when reported and
verified licensing evidence/reference. No full account/provider response dumps.
An editorial approval is not a licensing approval; both stay pending until checked.
No file enters the bundle until technical, listening and licensing reviews pass.
Do not claim the placeholder manifest's hashes/provenance for a generated replacement.

## Existing material preserved

[sound-effects-brief.md](../sound-effects-brief.md) remains the original brief.
The catalogue supplies canonical **future** IDs/filenames; its numbered loop names
supersede that brief's unnumbered proposed loop names, which were never wired.
The five legacy filename groups are unchanged.

[sound-audition/README.md](../sound-audition/README.md), its 24-request timbre pilot,
and `personal-requests.json` are separate prepared workflows. They use four timbre
families or synthetic named voice motifs; do not silently relabel them as the
three legacy voice indexes. No existing request ledger or waveform was changed.

Offline catalogue check (no provider, credentials, build or audio generation):

```sh
python3 script/verify_audio_catalogue.py
```

The check validates queue consistency and that all 15 bundled placeholder hashes
remain unchanged. It does not certify future generated audio or its licensing.
