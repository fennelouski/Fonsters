#!/bin/bash
set -euo pipefail
TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve the existing-instance launch-argument issue and stop only our tracked
# local prototype before reopening its persistent, growing lobby.
exec "$TASK_DIR/script/build_and_run.sh" --verify --lobby
