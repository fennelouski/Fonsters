#!/bin/bash
set -euo pipefail
TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TASK_DIR"
python3 script/run_sound_pilot.py --execute
