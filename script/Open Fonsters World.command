#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build_and_run.sh" run --lobby --world-members 12 --personality-file .prototype-build/world-preview/personality.json
