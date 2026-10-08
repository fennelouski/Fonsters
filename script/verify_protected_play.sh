#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
CHECK_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/protected-play.XXXXXX")"
swiftc -target arm64-apple-macos15.0 -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/ProtectedPlayPolicy.swift Fonsters/ParentActionGate.swift \
 Fonsters/FeatureFlag.swift Fonsters/RandomTextFallbacks.swift script/verify_protected_play.swift -o "$CHECK_DIR/verify"
"$CHECK_DIR/verify"
