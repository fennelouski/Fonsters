# Native window and omni search

The Mac app quits when its last window closes. Command-Shift-F toggles native
full screen. All three Mac scenes hide the title bar and traffic lights while
retaining native resize, Command-W and window-menu behavior. A small top-center
handle moves the window; its X closes it. This uses SwiftUI hiddenTitleBar plus a
narrow AppKit bridge because hiddenTitleBar alone retains traffic lights.

Command-F opens the floating search bar on Mac. iOS keyboard routing is still
unverified: the latest Command-F UI test did not open search. The
same search icon is available in the lobby and care. The bar uses system material,
an adaptive multicolor edge and a short spring. Reduce Motion and the existing
static mode remove the spring. Return opens the first result, buttons open any
result, and Escape or X clears and closes search without leaving care.

Search is entirely on-device: current Fonsters, selected checked source interests,
private owned interest fields, earned shared-ritual counters and learned movements.
The existing ritual records are the searchable keepsakes; there is no separate
photo or collectible archive yet. Empty search suggests current Fonsters. Exact
and prefix matches rank first. Matching interests and keepsakes arrange their
owning Fonsters in the world; nonmatches wait at the sides. Selecting a result
opens that Fonster's existing care view. Clearing restores the original layout.

Visitors contribute checked interest references only, never imported free text or
private care memories. Search does not query providers, transmit text, alter share
links, migrate records or change appearance identity. Keyboard menus route through
their owning native window, avoiding duplicate actions in multiple windows.

## Verification

Run the Mac preview and native checks:

```sh
script/build_and_run.sh --verify --verify-manual \
  --personality-file evidence/omni-search/native-memory.json \
  --omni-ui-verification-file evidence/omni-search/native-checks.json
```

Adding `--verify-last-window-quit` creates one extra preview-only window, closes
the first, writes a `.two-windows` marker if the process survives, then closes the
last. An external PID check verifies termination. This flag requires verify-manual
and uses a synthetic in-memory roster; it never closes another app's windows.

Local evidence is ignored under `evidence/omni-search`. Physical-device keyboard,
iPad, manual VoiceOver, oldest-supported macOS and live iCloud remain untested.
The signed generic iPhone build does not install or interrupt the physical phone.

Current pending evidence (2026-10-09): Mac last-window termination passed using
an external PID check and a two-window survival marker. Seventeen of eighteen
current native window/search checks passed; fullscreen entry failed in that run,
although it passed in an earlier sixteen-check run. These window/search edits
remain uncommitted on `codex/frameless-omni-search`; they are excluded from the
separate camera PR. Do not describe this work as merged or fully verified.
