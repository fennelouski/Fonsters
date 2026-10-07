#!/bin/bash
set -euo pipefail
TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
# Full local preview, with separate synthetic memories. Normal lobby enrollment
# and the original app's saved creatures keep their existing files.
exec "$TASK_DIR/script/build_and_run.sh" --verify --lobby --world-members 12 \
  --personality-file "$TASK_DIR/.prototype-build/neighborhood-preview/personality.json"
