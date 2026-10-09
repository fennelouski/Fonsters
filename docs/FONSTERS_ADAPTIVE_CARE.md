# Adaptive care controls and name tags

Selecting a Fonster keeps the native world edge to edge. Narrow portrait views put the primary reactions and camera/microphone controls in two compact bottom rows. Wide and short windows use short side rails. Appearance, feelings, and advanced mirroring remain available through Care; compact layouts put dance and privacy inside World and camera.

A small hanging-style name tag appears below the creature. Owners can tap it to edit the existing name/backstory/interests; visitor tags remain read-only. The name supports Dynamic Type and two lines. Reduce Motion removes its slight tilt and existing UI transitions remain motion-aware.

Care camera framing uses the measured unobstructed scene area, including safe areas and the dock, rather than shrinking the native renderer. Orbit, pan, zoom, keyboard navigation, and the existing lobby/detail orientation policy are preserved. Direct camera/microphone controls still disappear only after denied permission; education and parent checks remain in place.

Verification evidence is in the ignored local `evidence/adaptive-care` directory. This change requires no data migration, account, new service, or phone permission.

## Local verification

- Native Mac preview build and launch: passed; actual wide and narrow window screenshots and six-second silent ScreenCaptureKit clip captured.
- Signed generic iPhone build: passed, including a final incremental build of the reviewed source.
- iPhone simulator: six distinct UI tests passed across the first and final runs (3/3 and 5/5). They cover compact control geometry and 44-point targets, accessibility XXXL text, spatial search/petting/repeated reactions/return, portrait/landscape transitions, nested microphone education/parent approval, and editable name tag/profile persistence.
- Physical iPhone: deliberately not reinstalled or interrupted during this refinement; its previous main build remains available for Nathan's testing.
- iPad, VoiceOver speech, and physical camera/microphone tracking: not exercised in this refinement.

Run the preview with `script/build_and_run.sh --verify --verify-manual --dance-preview daylight --dance-preview-care`. Add `--care-preview-size 520x740` to inspect the compact Mac layout; this verification flag resizes only the app's own window.

The secondary privacy/gallery test initially failed because its dismissal helper checked for the underlying panel before the parent-check sheet finished easing out. Reviewing the test recording confirmed the panel returned correctly. The helper now waits for a hittable close button. Its focused retry passed (1/1) and is recorded in `panels-retry-ui.xcresult`. All seven distinct UI tests passed; no unresolved failed checks remain.
