#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$REPO_DIR/.prototype-build/Build/Products/Debug/Fonsters.app"
if [[ ! -d "$APP_PATH" ]]; then
  printf '%s\n' 'Build the Mac preview first with script/build_and_run.sh.'
  exit 1
fi
open "$APP_PATH" --args --prototype --verify-manual --personality-file "$REPO_DIR/.prototype-build/world-preview/personality.json"
