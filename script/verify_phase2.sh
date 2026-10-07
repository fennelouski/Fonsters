#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
FIXTURE_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/phase2.XXXXXX")"
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/Playroom/CreatureFur.swift Fonsters/Playroom/CreatureRig.swift Fonsters/Playroom/CreaturePersonality.swift Fonsters/Playroom/CreatureSoundBank.swift \
 Fonsters/Playroom/CreatureCommandIntent.swift Fonsters/Playroom/TypedActionInterpreter.swift \
 Fonsters/Playroom/CreatureSocialModels.swift Fonsters/Playroom/FriendshipMemoryStore.swift Fonsters/Playroom/PlayroomController.swift Fonsters/Playroom/LobbyWorld.swift Fonsters/Playroom/LobbyWorldScene.swift Fonsters/Playroom/LocalLobbySimulation.swift Fonsters/Playroom/LocalLobbyController.swift \
 script/verify_phase2.swift -o .prototype-build/verification/phase2
.prototype-build/verification/phase2 --verify-command-fallback --personality-file "$FIXTURE_DIR/memories.json"
if [[ "${1:-}" == "--live-model" ]]; then .prototype-build/verification/phase2 --live-model --personality-file "$FIXTURE_DIR/memories.json"; fi
