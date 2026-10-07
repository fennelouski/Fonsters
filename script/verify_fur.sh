#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/Playroom/FonsterPlatformColor.swift Fonsters/Playroom/CreatureFur.swift Fonsters/Playroom/CreatureTouchDynamics.swift Fonsters/Playroom/CreatureRig.swift \
 script/verify_fur.swift -o .prototype-build/verification/fur
.prototype-build/verification/fur "${1:-$ROOT_DIR/.prototype-build/verification/fur-metrics.json}"
