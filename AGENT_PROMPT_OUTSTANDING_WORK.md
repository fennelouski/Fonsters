# Prompt for AI Agent: Outstanding Work and Completion Plan

**Role:** You are an AI agent tasked with reading through the Fonsters project, identifying any outstanding TODOs and incomplete work, and producing a concrete plan to complete them.

**Current status (as of last update):** The original outstanding-work plan has been **completed**. All items (open-from-URL, tvOS target, watchOS target, visionOS voxels + arm animation, Prepend random, local random-text fallback) are implemented. **DOCUMENTATION.md** is the single source of truth for “What works” and for **Remaining work / to-dos** (optional items and environment notes only).

---

## Your tasks (when re-running this prompt)

1. **Read and synthesize**
   - Read **DOCUMENTATION.md** in the project root. Use the “What works” and “Remaining work / to-dos” sections as the current state.
   - Skim the main app code: **Fonsters/FonstersApp.swift**, **Fonsters/ContentView.swift**, **Fonsters/Fonster.swift**, **Fonsters/ShareLoadHelpers.swift**, and **Fonsters/CreatureAvatar/** (including **CreatureVoxelView.swift**). Use file headers and comments for structure and intent.
   - Search the repo for any TODO/FIXME/HACK/XXX or “not implemented” / “deferred” references to build a list of any new or leftover work.

2. **List all outstanding work**
   - Enumerate anything still marked not implemented, deferred, or optional in DOCUMENTATION.md and in code comments.
   - For each item: (a) where it is documented or referenced, (b) platform if relevant, (c) required vs optional/deferred.

3. **Produce a completion plan**
   - For any remaining work, write a **prioritized, actionable plan** (Id, Description, Dependencies, Suggested steps, Acceptance).
   - If there is no remaining work, say so and point to DOCUMENTATION.md “Remaining work / to-dos” for optional/future items.

4. **Output**
   - Put the outstanding-work list and completion plan in a single response or in a markdown file (e.g. `OUTSTANDING_WORK_PLAN.md`). If creating a file, note it in your reply.

---

## Quick reference

- **Current state and remaining to-dos:** `DOCUMENTATION.md` → “What works” and “Remaining work / to-dos”.
- **App entry and schema:** `Fonsters/FonstersApp.swift`.
- **Main UI and platform conditionals:** `Fonsters/ContentView.swift`.
- **Share/Import and URL handling:** `Fonsters/ShareLoadHelpers.swift` (open from URL is implemented via `fonsters://`).
- **Creature rendering:** `Fonsters/CreatureAvatar/` (2D and visionOS 3D voxel).
- **Watch app:** `Fonsters Watch App/*.swift`.
- **Xcode targets:** `Fonsters.xcodeproj/project.pbxproj`.

Use this prompt to re-check for outstanding work and to extend the completion plan if new tasks are added.
