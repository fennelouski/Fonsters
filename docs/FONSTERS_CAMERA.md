# Camera mirroring

The main continuous lobby keeps explicit camera intent for the current window.
Leaving owned care, visiting another profile, opening a review/search field,
pausing, backgrounding or entering Low Power stops capture and rejects late
samples. Returning to usable owned care resumes capture only while that intent
is still on. The camera button and Stop inputs clear it; returning does not
undo a manual off. Microphone intent continues to clear on detail navigation.

Only device-local timestamps are retained. First use, or at least 30 days since
both the last approved review and camera activity, presents the simulated
education, grown-up review, then device permission. Recent approved review or
use skips that walkthrough when re-enabling. An expired automatic resume
stops at the walkthrough instead of reopening hardware silently. The review timestamp is written
only after the grown-up check succeeds. Permission denial hides the button.
There are no saved frames, faces, transcripts or identity templates.

New multiplication questions use factors 2–10: products stay below 100 except
when a factor is 10. This is an accidental-access check, not age assurance.

A camera face takes priority over peer gaze and old pointer-follow state. It
looks towards the scene camera without the idle 3–15° upward offset and follows
horizontal/vertical face position smoothly. Missing faces return to normal gaze;
Reduce Motion/static mode freeze animation as before.

## Hand reactions

| Signs held in camera | Reaction |
| --- | --- |
| One thumbs up | Wave hello |
| Two thumbs up | Dance |
| One peace sign | Hop |
| Two peace signs | Twirl |
| One thumbs down | Settle into a soothing rub |
| Two thumbs down | Stretch |
| Thumbs up + peace | High five |
| Thumbs up + thumbs down | Curious look |
| Peace + thumbs down | Blink |

Apple Vision hand joints are confidence-filtered and classified locally. Hold a
sign for 0.55 seconds; there is a 1.6-second event cooldown. A held sign fires
once; releasing for 0.4 seconds rearms it. Different signs replace a reaction,
never queue it. Up to eight hands/four faces are considered. Hand-to-person
assignment uses nearest horizontal face position; crossed hands and occlusion
can be ambiguous. FaceTime's system video overlays are not requested.

Primary API guidance: [Apple hand pose documentation](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest)
and [Apple hand-pose sample](https://developer.apple.com/documentation/vision/detecting-hand-poses-with-vision).

## Checks

`script/verify_mirroring.sh` verifies isolated history boundaries, ten thousand
math questions, numeric pose classification, gesture hold/release/cooldown,
capture suspension/manual off, speech routing and local personality persistence.
`script/verify_faces.sh` checks actual RealityKit eye/head directions, expressions
and motion gates. `WelcomeAndSensesTests` exercises camera education and detail
navigation using synthetic inputs; it never opens camera/microphone hardware.
Live camera gestures, lighting/occlusion and physical-device testing remain
manual checks. Local evidence is under ignored `evidence/camera-refinement`.

Verified locally on 2026-10-09: native Mac build; 79 mirroring/history/gesture
checks; 29 protected-play checks; six face/rig check groups; both first-friend
and camera navigation simulator tests; six native view lifecycle checks. Actual
simulator screenshots and a native window clip are retained as local evidence.
The clip uses numeric synthetic camera cues, not a live-camera recording.

For a native numeric demonstration, launch the preview with `--prototype`,
`--verify-manual`, `--verify-live-inputs`, `--camera-lifecycle-proof` followed by
an absolute JSON output path, and `--camera-numeric-demo`. Give the run an
isolated `--camera-history-suite` and `--personality-file`. Normal previews omit
`--verify-live-inputs` so the visible camera button controls real capture.
