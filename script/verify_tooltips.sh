#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROOF_DIR="$(mktemp -d /tmp/fonsters-tooltip.XXXXXX)"
# Compile the actual native tooltip in a small harness, with an injected pointer
# location. No system cursor movement, accessibility grant, or screen capture.
python3 - "$REPO_DIR" "$PROOF_DIR" <<'PY'
import pathlib, sys
root, proof = map(pathlib.Path, sys.argv[1:])
source = (root / 'Fonsters/Playroom/FonsterVisualControls.swift').read_text()
start = source.index('private struct FonsterMacTooltip:')
end = source.index('\n#endif', start)
(proof / 'main.swift').write_text('import SwiftUI\nimport AppKit\nimport QuartzCore\n' + source[start:end] + '\n' + (root / 'script/verify_tooltips.swift').read_text())
PY
swiftc -parse-as-library -target arm64-apple-macos15.0 "$PROOF_DIR/main.swift" -o "$PROOF_DIR/verify"
"$PROOF_DIR/verify"
