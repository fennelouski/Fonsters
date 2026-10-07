#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift \
 Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/Playroom/CreatureFur.swift Fonsters/Playroom/CreatureTouchDynamics.swift Fonsters/Playroom/CreatureRig.swift Fonsters/Playroom/CreaturePersonality.swift Fonsters/Playroom/FonsterAgentModels.swift Fonsters/Playroom/CreatureSoundBank.swift Fonsters/Playroom/CreatureCommandIntent.swift Fonsters/Playroom/CreatureSocialModels.swift Fonsters/Playroom/FriendshipMemoryStore.swift Fonsters/Playroom/PlayroomController.swift \
 script/verify_motion.swift -o .prototype-build/verification/motion
.prototype-build/verification/motion
