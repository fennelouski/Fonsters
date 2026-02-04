# macOS Keyboard Shortcuts Plan

## 1. Sidebar Toggle (Command + Option + `)

- **Current:** [Fonsters/ContentView.swift](Fonsters/ContentView.swift) uses a two-column `NavigationSplitView` (master list + detail) with no `columnVisibility` binding.
- **Add:** `@State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn` and use `NavigationSplitView(columnVisibility: $columnVisibility) { ... } detail: { ... }`.
- **Toggle:** A macOS-only toolbar button that sets `columnVisibility = (columnVisibility == .doubleColumn ? .detailOnly : .doubleColumn)` with `.keyboardShortcut(KeyEquivalent("`"), modifiers: [.command, .option])`.

## 2. Go to Fonster by Position (Command + 1 … Command + 0)

- **Behavior:** Command+1 → first Fonster, Command+2 → second, … Command+9 → ninth, **Command+0 → tenth** (0 = 10th, standard convention).
- **List order:** `fonsters` is `@Query(sort: \Fonster.createdAt, order: .reverse)`; selection is `selectedId: Fonster.ID?`. Position N (1-based) = `fonsters[N - 1]`; position 10 = Command+0 → `fonsters[9]`.
- **Logic:** For each shortcut, if the list has at least N items, set `selectedId = fonsters[index].id` where index is 0 for Cmd+1, 1 for Cmd+2, … 9 for Cmd+0. If there are fewer than N items, no-op (or optionally select last item; plan assumes no-op).
- **Implementation (macOS only):** Add 10 key commands without adding 10 visible UI elements. Options:
  - **A. Hidden buttons:** An overlay or `background { }` containing 10 `Button`s, each with `.keyboardShortcut(KeyEquivalent(Character("1")), modifiers: .command)` through `.keyboardShortcut(KeyEquivalent("0"), modifiers: .command)`. Buttons can be empty-label and hidden. Map digit to index: digit "0" → index 9, digits "1"–"9" → index 0–8.
  - **B. Menu commands:** Use `.commands { }` in the app/scene and add a "Go to Fonster" submenu with 10 items (e.g. "First Fonster", "Second Fonster", … "Tenth Fonster") each with the corresponding shortcut. More discoverable but adds menu items.
- **Recommendation:** Option A keeps the UI minimal; Option B is more discoverable. Plan assumes Option A unless you prefer a menu.

**Concrete (Option A):** In ContentView, add a private helper e.g. `func selectFonsterAt(position: Int)` where position is 1...10 (1 = first, 10 = tenth). If `position <= fonsters.count`, set `selectedId = fonsters[position - 1].id`. Then add a macOS-only modifier (e.g. on the `NavigationSplitView` or its root) that presents 10 hidden buttons:

- For N in 1...9: `Button("") { selectFonsterAt(position: N) }.keyboardShortcut(KeyEquivalent(Character(Unicode.Scalar(48 + N)!)), modifiers: .command)` — digits "1"–"9" are ASCII 49–57, so Character("1") = 49. Simpler: use `KeyEquivalent(Character("\(N)"))` for N in 1...9, and for N=10 use `KeyEquivalent("0")`.
- So: one Button for each of 1...10, with key "1", "2", … "9", "0" and action `selectFonsterAt(position: n)` where n is 1...10.

## Files to change

- **Fonsters/ContentView.swift**
  - Add `columnVisibility` state and binding to `NavigationSplitView`; add sidebar-toggle toolbar button with Command+Option+` (macOS only).
  - Add `selectFonsterAt(position:)` and the 10 hidden shortcut buttons (macOS only), attached to the same view that has the split (so they are in the key view hierarchy).

## Summary

| Shortcut           | Action                          |
|--------------------|---------------------------------|
| Command+Option+`   | Toggle master list visibility   |
| Command+1 … 9      | Select 1st … 9th Fonster        |
| Command+0          | Select 10th Fonster             |
