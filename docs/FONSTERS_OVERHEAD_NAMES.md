# Overhead Fonster names

Selecting a Fonster by touching it (or the equivalent search/keyboard selection)
shows its name above its live 3D body. The label follows the creature and camera
in solo care and exploration. Returning to the lobby hides it. Offscreen or
behind-camera creatures do not leave a detached label pinned to a window edge.
The old footer name tag, decorative handle, card outline and tilted badge are
removed.

A small adaptive contrast backing keeps the name legible against the world.
Names respect Dynamic Type and truncate visually while retaining their complete
accessible value. Owned names remain an edit target with a minimum 44-point hit
area and Mac hover help. Visitor names remain read-only. Legacy portrait fallback
creatures also use their actual rendered bounds for the name anchor. No stored
name, seed, appearance, export or share-link identity is changed.

Verification on the MacBook Air, 2026-10-09:

- Native Mac build and actual care-window screenshot.
- Native own-window walk/pan/pet checks plus name-above-creature, name-following-
  camera-pan and name-hidden-after-return checks.
- iPhone simulator portrait care, accessibility text, landscape exploration and
  owned-profile editing checks.
- Signed generic iPhone build; no physical-phone install.

Local logs, xcresults, screenshots and `mac-interactions.json` are in ignored
`evidence/overhead-names`. Physical-device interaction, iPad and manual VoiceOver
remain untested.
