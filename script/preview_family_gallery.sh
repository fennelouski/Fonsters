#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
case "$MODE" in prepare|run) ;; *) echo 'Usage: preview_family_gallery.sh [prepare|run]'; exit 64 ;; esac
mkdir -p .prototype-build
SESSION_DIR="$(mktemp -d /tmp/fonsters-family-gallery.XXXXXX)"
printf '%s\n' "$SESSION_DIR" > .prototype-build/last-family-gallery-path
if [[ "$MODE" == run ]]; then
 APP="$ROOT_DIR/.prototype-build/native/Build/Products/Debug/Fonsters.app"
 [[ -d "$APP" ]] || { echo 'Build the native preview first.'; exit 1; }
 /usr/bin/open -n "$APP" --args --prototype --family-gallery --personality-file "$SESSION_DIR/personality.json" --lobby-probe-file "$SESSION_DIR/lobby-probe.json" --window-export-file "$SESSION_DIR/gallery-ui-scene.png" --window-export-target lobby --window-export-delay 8 --ui-scene-photo
fi
printf 'Memory-only family gallery: %s\n' "$SESSION_DIR"
