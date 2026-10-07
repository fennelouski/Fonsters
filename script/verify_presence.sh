#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
FIXTURE_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/presence.XXXXXX")"
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/CreatureAvatar/CreatureTypes.swift Fonsters/CreatureAvatar/CreatureConstants.swift \
 Fonsters/CreatureAvatar/CreatureHash.swift Fonsters/CreatureAvatar/CreatureGenerator.swift Fonsters/CreatureAvatar/CreatureRaster.swift \
 Fonsters/Playroom/ResolvedCreatureTrace.swift Fonsters/Playroom/CreatureAppearanceDescriptor.swift \
 Fonsters/Playroom/CreatureFur.swift Fonsters/Playroom/CreatureTouchDynamics.swift Fonsters/Playroom/CreatureRig.swift Fonsters/Playroom/CreaturePersonality.swift Fonsters/Playroom/CreatureSoundBank.swift \
 Fonsters/Playroom/FonsterAgentModels.swift Fonsters/Playroom/FonsterAgentDirector.swift Fonsters/Playroom/FonsterSocialPresence.swift Fonsters/Playroom/FonsterSocialDirector.swift \
 Fonsters/Playroom/CreatureSocialModels.swift Fonsters/Playroom/FriendshipMemoryStore.swift Fonsters/Playroom/CreatureCommandIntent.swift \
 Fonsters/Playroom/PlayroomController.swift Fonsters/Playroom/LobbyWorld.swift Fonsters/Playroom/LobbyWorldScene.swift \
 Fonsters/Playroom/LocalLobbySimulation.swift Fonsters/Playroom/LocalLobbyController.swift Fonsters/Playroom/FonsterVisitDocument.swift \
 Fonsters/Playroom/CreatureStageView.swift Fonsters/Playroom/TouchGestureVerification.swift Fonsters/Playroom/CreatureSceneLighting.swift Fonsters/Playroom/NativeSceneExport.swift \
 Fonsters/Playroom/FonsterSocialStudio.swift Fonsters/Playroom/VerificationWindowCapture.swift \
 script/verify_presence.swift -o .prototype-build/verification/presence
.prototype-build/verification/presence "$FIXTURE_DIR" --personality-file "$FIXTURE_DIR/personality.json"
