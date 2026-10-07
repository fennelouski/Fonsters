#!/bin/bash
set -euo pipefail
TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TASK_DIR/script/build_and_run.sh" --verify --lobby --world-members 12 --agent-studio \
  --personality-file "$TASK_DIR/.prototype-build/agent-preview/personality.json"
