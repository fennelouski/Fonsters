# Agent prompt: Fix tvOS sidebar list focus and spacing

## Goal
On **tvOS**, fix two issues in the main sidebar list (Fonsters list):

1. **Selected/focus area is too large** — The white rounded focus ring around the selected row extends far beyond the row content (icon + name), so it feels oversized and overlaps the visual space of adjacent rows.
2. **List items are too close together** — Vertical spacing between rows is too tight; the list feels cramped.

A previous attempt only adjusted padding and `listRowInsets` in `ContentView.swift` (reduced row padding to 8pt, removed inner padding, set list row top/bottom insets to 12). **That did not fix the problem.** The focus ring is still drawn very large and spacing still feels insufficient.

## What you must do
1. **Investigate why the focus ring is so large on tvOS.**  
   On tvOS, SwiftUI’s `List` + `NavigationLink` uses the system focus ring. The ring is drawn around the focusable content. Consider:
   - Whether the **focus ring is being applied to a larger view** than intended (e.g. the whole row including extra padding or `Spacer()`s).
   - tvOS APIs that control **focus ring size or shape** (e.g. `focusEffectDisabled`, custom focus modifiers, or replacing `NavigationLink` with a `Button` and custom navigation).
   - Using a **different list row structure** so the focusable region is only the icon + text (e.g. no `VStack` with `Spacer()`s, or a custom focusable wrapper with tight bounds).
2. **Increase vertical spacing between list rows** so items are clearly separated.  
   If `listRowInsets` alone is not enough, consider other mechanisms (e.g. `listRowSpacing`, list style, or extra spacing in the row content) that actually affect the rendered gap on tvOS.
3. **Implement a fix** that:
   - Makes the **visible focus/selection area** noticeably smaller and closer to the row content.
   - Makes **vertical spacing between list items** noticeably larger.

## Relevant code
- **File:** `Fonsters/ContentView.swift`
- **List:** `sidebarFonstersList` — `List(selection: $selectedId)` with `ForEach(fonsters)` and `NavigationLink(value: fonster.id) { sidebarRow(for: fonster) }`.
- **Row:** `sidebarRow(for:)` — On tvOS: `VStack { Spacer(); sidebarRowContent(for: fonster); Spacer() }.padding(8)`.
- **Row content:** `sidebarRowContent(for:)` — `HStack` with `CreatureAvatarView` (48pt), `Text(displayName(for:))`, optional “Birthday!”.
- **tvOS list row insets** (Fonster rows): `listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))`.
- **“How to use Fonsters”** row also has tvOS `listRowInsets` (top/bottom 12).

Build and run the **Fonsters** app on **tvOS Simulator** (e.g. Apple TV 4K) and confirm the sidebar list: the selected row’s focus ring should be tighter around the content, and there should be more vertical space between rows.
