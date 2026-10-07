#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
./script/build_and_run.sh --verify --personality-file "$ROOT_DIR/.prototype-build/visual-interactive/personality.json"
