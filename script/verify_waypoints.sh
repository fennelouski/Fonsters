#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .prototype-build/verification
FIXTURE_DIR=$(mktemp -d .prototype-build/verification/waypoints.XXXXXX)
swiftc -target arm64-apple-macos15.0 -module-cache-path .prototype-build/verification/modules Fonsters/Playroom/LobbyWaypoints.swift Fonsters/Playroom/LobbyMappedWorld.swift script/verify_waypoints.swift -o .prototype-build/verification/waypoints
.prototype-build/verification/waypoints "$FIXTURE_DIR"
swiftc -target arm64-apple-macos15.0 -module-cache-path .prototype-build/verification/modules Fonsters/Playroom/LobbyPresentation.swift script/verify_lobby_presentation.swift -o .prototype-build/verification/presentation
.prototype-build/verification/presentation
