#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Capture the secure OS prompt in Python memory, never shell output or arguments.
/usr/bin/python3 - <<'PY'
from pathlib import Path
import os, subprocess, secrets
config = Path('.env.interests')
if config.exists():
    print('Existing private backend configuration is preserved. Edit it locally if needed.')
    raise SystemExit(0)
script = '''set response to display dialog "Paste your existing TypeSafe Jev API key. It will be saved only in this Fonsters checkout's private server configuration, never in the app or Git." default answer "" with hidden answer buttons {"Cancel", "Save locally"} default button "Save locally" cancel button "Cancel" with title "Fonsters backend setup"
return text returned of response'''
result = subprocess.run(['/usr/bin/osascript', '-e', script], capture_output=True, text=True)
if result.returncode:
    print('Setup cancelled; no configuration changed.')
    raise SystemExit(0)
key = result.stdout.strip()
if not key or len(key) > 512 or any(c.isspace() for c in key):
    print('The key was empty or malformed; no configuration changed.')
    raise SystemExit(1)
# A developer-preview secret has no account/OAuth capability and is never shown.
content = 'JEV_API_KEY=' + key + '\nINTEREST_PREVIEW_ENABLED=true\nINTEREST_PREVIEW_ACCESS_KEY=' + secrets.token_urlsafe(32) + '\nINTEREST_REVIEWED_PROVIDERS=wikipedia\n'
try:
    fd = os.open(config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    print('Another setup window already saved the private configuration. It is preserved.')
    raise SystemExit(0)
with os.fdopen(fd, 'w') as file: file.write(content)
print('Saved private server configuration. Start with npm run dev:interests. No account or public app service was enabled.')
PY
