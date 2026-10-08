#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .prototype-build/verification
CHECK_DIR="$(mktemp -d "$ROOT_DIR/.prototype-build/verification/personality.XXXXXX")"
swiftc -module-cache-path "$ROOT_DIR/.prototype-build/verification/modules" \
 Fonsters/Playroom/CreatureMirroring.swift Fonsters/Playroom/CreaturePersonality.swift script/verify_personality.swift -o "$CHECK_DIR/verify"
"$CHECK_DIR/verify" "$CHECK_DIR"
