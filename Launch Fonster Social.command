#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
./script/build_and_run.sh --verify --lobby --world-members 12 --presence-preview --presence-studio --personality-file "$ROOT_DIR/.prototype-build/presence-preview/personality.json"
