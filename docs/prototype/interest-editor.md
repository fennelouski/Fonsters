# Adaptive profile editor and source chips

The editor and older playroom surfaces now follow the system's light/dark
appearance. Shared `FonsterChrome.xcassets` is compiled into every native target,
including Watch, Clock and Messages. Opaque text surfaces carry explicit semantic
foregrounds; selected icons have a separate adaptive foreground. Artwork and
chosen stage lighting retain their existing appearance identity.

A measured sRGB contrast pass covers 48 foreground/background pairs in both
appearances, minimum 5.85:1 against the 4.5:1 body-text floor. Disabled controls
are visually distinct; font sizes remain native and support accessibility sizes.
Run `python3 script/verify_contrast.py` to measure the actual shared assets.
System blur/material and user-supplied artwork are not guaranteed by that opaque
palette calculation and require native visual review.

The editor's camera icon reuses opt-in parent review and on-device Vision inputs.
It stops on dismissal or choosing a different draft appearance; scene inactivity, low power and
Reduce Motion suspend capture and animation. No frames or numeric facial samples
enter the profile. The existing care-screen camera remains available.

Interest fields keep raw text privately; debounce/cancellation separates typing
from chosen canonical references. The small checked local catalog is labeled
honestly. Use the plus/count badge to browse, swipe or use arrows, select more
than one source, and tap again to remove a selection. Chips open source details
with a recipient preview. Source browser navigation requires parent review.
Reduced Motion removes the presentation's spring. Field reset restores the whole
unsaved draft, including source selections; X discards it; checkmark persists it.

Existing optional JSON storage is extended without changing appearance seeds or
SwiftData schema fields. Music/place private lists and optional ID selections
coexist with legacy profile fields. Version 1 and 2 visit files still decode.
New version 3 exports contain catalog IDs and finite category enums, never raw
biography/favorites, typed drafts, seed or private identifiers. Unknown IDs or
injected labels/URLs are rejected. Visitor care renders only records resolved
from the checked catalog, and hides imported legacy free text. This is local
snapshot sharing; no public social service is enabled.

[Backend service, actual provider boundaries and setup](../backend/interests.md)
explains the separate developer-preview service. Provider identity evidence is
not public approval, endorsement or suitability for children.
