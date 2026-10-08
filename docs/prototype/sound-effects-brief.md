# Fonsters sound effects handoff

Owner direction: friendly fuzzy creatures, very little on-screen explanation, and sound that makes a touch or a shared moment feel alive. Another worker will generate audio with an API. This brief does not authorize spending, account creation, or uploading user data. No new API calls or paid generation were made for this UI pass.

## Delivery

Place production-ready, original/licensed clips in `Fonsters/Playroom/Sounds/`. First deliver the 15 replacement clips below: the existing `CreatureSoundBank` already loads these exact names. Three voices are **Warm** (round, breathy), **Clear** (small, bright), and **Bright** (playful, slightly chirpy), indexed `0`, `1`, and `2`. Keep identities related without merely pitching the same recording. They are nonverbal characters: no speech, real-person imitation, screams, distress, punishment, or notification alarms.

Use PCM WAV, mono, 44.1 kHz, 16-bit; no leading silence beyond 20 ms; short fade-in/out, clean tail, no clipping, peak at or below −3 dBFS. Aim around −22 LUFS integrated for longer clips; audition short chirps against the existing bank at comfortable quiet volume. These are suggested mix targets, not validated measurements of the current clips. Never increase system volume. Include a manifest with filename, duration, sample rate, licensing/provenance, voice, event, and loudness/peak measurements. Include a dry version; spatialization belongs in the app.

| Existing filename pattern (each needs `_0`, `_1`, `_2`) | Trigger | Direction | Duration |
| --- | --- | --- | --- |
| `fonster_greet_N.wav` | Wave, high five, welcome | Two soft rising notes; smiling creature hello | 0.3–0.7 s |
| `fonster_play_N.wav` | Play, hop, twirl, ball | Bouncy rounded giggle/chirp; delight, no speech | 0.4–0.9 s |
| `fonster_rest_N.wav` | Rest, stretch, gentle rub | Tiny contented sigh/purr, warm and quiet | 0.6–1.2 s |
| `fonster_blink_N.wav` | Explicit blink | Barely audible rounded squeak; no click or alarm | 0.08–0.2 s |
| `fonster_look_N.wav` | Curious look | Small questioning “oo” style nonverbal chirrup | 0.2–0.5 s |

`N` above is a placeholder, not a literal filename: e.g. `fonster_greet_0.wav`. Existing files are original procedural placeholder chirps and remain usable until reviewed replacements arrive. Do not overwrite them without preserving reviewable provenance and checking playback.

## Next event bank (requires explicit app wiring)

Do not imply these are already played. Start with 3 distinct takes per event/voice, then grow only after listening and testing. Thousands of files are a later library goal; variety should serve a recognizable character rather than download size.

| Proposed filename | Visible event | Sound | Duration / variants |
| --- | --- | --- | --- |
| `touch_stroke_V_T.wav` | Slow pet, relaxed eyelids | Soft fluffy rub + almost-purr | 0.3–0.7 s / 3 takes |
| `touch_cuddle_V_T.wav` | Held gentle contact | Settling hum, rounded and cuddly | 0.6–1 s / 3 |
| `touch_tickle_V_T.wav` | Belly touch | Tiny bubbling giggle, no human voice | 0.3–0.7 s / 4 |
| `touch_highfive_V_T.wav` | Paw high five | Soft padded tap + little happy chirp | 0.15–0.4 s / 3 |
| `touch_surprise_V_T.wav` | Quick swipe, happy recoil | Brief curious squeak; never pain or fear | 0.15–0.35 s / 3 |
| `friend_wave_V_T.wav` | Two Fonsters greet | Short call and answer; each voice identifiable | 0.4–0.8 s / 3 |
| `friend_ball_pass_T.wav` | Ball leaves / lands | Quiet cloth-like bounce and padded catch | 0.1–0.25 s / 4 |
| `friend_quiet_V_T.wav` | Companions settle together | Soft comfortable breath/hum | 0.5–1 s / 3 |
| `world_step_grass_T.wav` | Walking on grass | Tiny muffled fuzzy footsteps | 0.08–0.2 s / 6 |
| `world_step_path_T.wav` | Walking on path | Light padded step, no hard shoe heel | 0.08–0.2 s / 6 |
| `world_bench_settle_T.wav` | Sit on bench | Subtle cushion/wood settling | 0.2–0.5 s / 3 |
| `world_fountain_loop.wav` | Fountain nearby | Gentle small fountain, seamless, no loud hiss | 8–12 s / 1 |
| `world_park_loop.wav` | Park nearby | Air through leaves, very sparse soft birds | 10–15 s / 1 |
| `world_seaside_loop.wav` | Seaside setting | Gentle distant surf and airy shore breeze; seamless and quiet | 12–18 s / 1 |
| `world_moonlit_loop.wav` | Moonlit garden setting | Soft night air, sparse friendly crickets; no spooky or startling sounds | 12–18 s / 1 |
| `ui_select_T.wav` | Avatar/area selection | Small soft wooden/padded note | 0.08–0.15 s / 3 |
| `ui_confirm.wav` | Owner approves local action/save | Two soft notes, no reward fanfare | 0.2–0.4 s / 1 |
| `ui_cancel.wav` | Cancel/take over | Single quiet falling note | 0.1–0.2 s / 1 |
| `world_area_open.wav` | Real population opens an area | Brief airy chime; use sparingly | 0.4–0.8 s / 1 |

`V` = `warm`, `clear`, `bright`; `T` = `01`, `02`, etc. Keep one-shot and loop metadata explicit. No loops are wired in the present prototype.

## Playback requirements for the integrating worker

- Sound stays opt-in. A favorite voice can be auditioned only with sound enabled.
- Touch cannot fire sound on every pointer sample. Retain the current cooldown, small voice limit, and interruptible playback; continuous rubbing must never form an audio pile-up.
- Silence on pause, background, low power, and sound-off. Respect Static/Reduce Motion gates and the existing action behavior; never use audio to evade a paused agent.
- No audio recording is needed. Microphone commands use on-device speech; camera mirroring uses local landmarks and body cues. Do not send audio, words or frames to generation APIs.
- Sound supplements visible action and accessible status; it is never the only indication of a choice, error, consent, or state.
- Review all voices at quiet volume on the Air speakers and headphones. Verify no clipping, abrupt cuts, duplicate playback, restart storm, or seamless-loop click. Record exactly which checks ran.

## Dance world and imitation additions

Generate original nonverbal, soft sounds; no recognizable song or artist imitation. Supply dry mono 44.1 kHz 16-bit WAV plus licensed provenance and catalog IDs. Audio stays off during microphone commands to avoid feedback.

| Cue | Length | Requested variations |
| --- | --- | --- |
| Spotlight welcome | 0.5–1 s | Warm ascending felt mallet + tiny creature breath, 4 |
| Disco entrance | 1–2 s | Playful restrained bass/mallet flourish, 4 |
| Dance loop | 8–16 s, seamless | Gentle toy disco grooves at 75/95/115 BPM, instrumental, 6 |
| Confetti burst | 0.3–0.8 s | Soft paper flutter with a tiny pop, 4 |
| Balloon arrival | 0.4–0.8 s | Gentle rubber squeak and airy wobble, no startling pop, 4 |
| Practice begins | 0.3–0.6 s | Two inviting soft notes, 4 |
| Practice progress | 0.15–0.3 s | Quiet bell accent, throttle to milestones, 4 |
| Learned movement kept | 0.5–0.9 s | Friendly satisfied hum with a soft two-note resolution, 6 |
| Blink / wake / settle | 0.2–0.7 s | Eyelid flutter, tiny yawn, warm waking chirp, 6 each |
| Mirrored wave | 0.4–0.8 s | Breathy hello, tonal rather than spoken words, 8 |

No audio generation call was made for these additions. The party currently relies on the existing opt-in action chirps; the requested loops are not presented as generated or installed assets.
