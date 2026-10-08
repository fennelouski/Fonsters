#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
FIXTURE_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/touch.XXXXXX")"
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/Playroom/FonsterPlatformColor.swift Fonsters/Playroom/CreatureFur.swift Fonsters/Playroom/CreatureTouchDynamics.swift Fonsters/Playroom/CreatureRig.swift Fonsters/Playroom/CreatureMirroring.swift Fonsters/Playroom/CreaturePersonality.swift Fonsters/Playroom/FonsterAgentModels.swift Fonsters/Playroom/CreatureSoundBank.swift \
 Fonsters/FonsterBiography.swift Fonsters/Playroom/CreatureSocialModels.swift Fonsters/Playroom/FriendshipMemoryStore.swift \
 Fonsters/Playroom/CreatureCommandIntent.swift Fonsters/Playroom/CompanionEnvironment.swift Fonsters/Playroom/PlayroomController.swift \
 Fonsters/Playroom/LobbyWorld.swift Fonsters/Playroom/LobbyWorldScene.swift Fonsters/Playroom/LocalLobbySimulation.swift Fonsters/Playroom/LobbyPresentation.swift Fonsters/Playroom/LobbyDanceScene.swift Fonsters/Playroom/LocalLobbyController.swift Fonsters/ProtectedPlayPolicy.swift Fonsters/Playroom/FonsterAgentDirector.swift Fonsters/Playroom/FonsterSocialPresence.swift Fonsters/Playroom/FonsterSocialDirector.swift \
 Fonsters/Playroom/FonsterVisualControls.swift Fonsters/Playroom/FonsterVisitDocument.swift \
 script/verify_touch.swift -o .prototype-build/verification/touch
.prototype-build/verification/touch "$FIXTURE_DIR" --personality-file "$FIXTURE_DIR/personality.json" "$@"
