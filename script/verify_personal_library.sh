#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
FIXTURE_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/personal.XXXXXX")"
# Exact pre-feature model, compiled in the same module. Never opens a user store.
git show e550dda027bfdb2ad07030c8fa8935abe903c3ea:Fonsters/Fonster.swift > "$FIXTURE_DIR/Fonster.swift"
cat > "$FIXTURE_DIR/MakeLegacy.swift" <<'SWIFT'
import Foundation
import SwiftData
@main struct MakeLegacy {
 @MainActor static func main() throws {
  let schema = Schema([Fonster.self])
  let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("legacy.sqlite")
  let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("LegacyMigration", schema: schema, url: url, cloudKitDatabase: .none)])
  container.mainContext.insert(Fonster(name: "Legacy Friend", seed: "do-not-change-legacy-seed", history: ["prior-seed"]))
  try container.mainContext.save()
 }
}
SWIFT
swiftc -module-name Fonsters -target arm64-apple-macos15.0 -module-cache-path .prototype-build/verification/modules "$FIXTURE_DIR/Fonster.swift" "$FIXTURE_DIR/MakeLegacy.swift" -o "$FIXTURE_DIR/make-legacy"
"$FIXTURE_DIR/make-legacy" "$FIXTURE_DIR"
swiftc -module-name Fonsters -target arm64-apple-macos15.0 -module-cache-path .prototype-build/verification/modules \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/FonsterInterests.swift Fonsters/FonsterBiography.swift Fonsters/Fonster.swift Fonsters/PersonalFonsterLibrary.swift Fonsters/Playroom/CreatureSocialModels.swift \
 script/verify_personal_library.swift -o "$FIXTURE_DIR/verify-personal"
"$FIXTURE_DIR/verify-personal" "$FIXTURE_DIR"
