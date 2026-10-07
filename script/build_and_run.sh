#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
if [[ $# -gt 0 ]]; then shift; fi
LAUNCH_ARGS=("$@")
# Finder/open does not inherit the shell's working directory. Resolve explicit
# archive/evidence paths before handing them to the native app.
EXPECT_PATH=false
for INDEX in "${!LAUNCH_ARGS[@]}"; do
  ARGUMENT="${LAUNCH_ARGS[$INDEX]}"
  if $EXPECT_PATH; then
    if [[ "$ARGUMENT" != /* ]]; then LAUNCH_ARGS[$INDEX]="$ROOT_DIR/$ARGUMENT"; fi
    EXPECT_PATH=false
  else
    case "$ARGUMENT" in
      --personality-file|--social-file|--probe-file|--lobby-probe-file|--scene-export-dir|--window-export-file|--sample-visit-file|--touch-evidence-dir) EXPECT_PATH=true ;;
    esac
  fi
done
HAS_SOCIAL_DEMO=false
HAS_AGENT_DEMO=false
HAS_PERSONALITY_FILE=false
for ARGUMENT in "${LAUNCH_ARGS[@]}"; do
  case "$ARGUMENT" in
    --social-demo) HAS_SOCIAL_DEMO=true ;;
    --agent-demo) HAS_AGENT_DEMO=true ;;
    --presence-demo|--presence-preview) HAS_AGENT_DEMO=true ;;
    --personality-file) HAS_PERSONALITY_FILE=true ;;
  esac
done
# Scripted demonstrations use their own synthetic memories, even when no test
# archive path was supplied. Normal interactive launches keep their existing file.
if $HAS_SOCIAL_DEMO; then
  DEMO_MEMORY_DIR="$ROOT_DIR/.prototype-build/native-social-demo"
  mkdir -p "$DEMO_MEMORY_DIR"
  if ! $HAS_PERSONALITY_FILE; then LAUNCH_ARGS+=(--personality-file "$DEMO_MEMORY_DIR/personality.json"); fi
  # The social store uses the personality path too, unless an explicit social
  # archive was supplied. Preserve both explicit archive choices.
fi
if $HAS_AGENT_DEMO && ! $HAS_PERSONALITY_FILE; then
  DEMO_MEMORY_DIR="$ROOT_DIR/.prototype-build/native-agent-demo"
  mkdir -p "$DEMO_MEMORY_DIR"
  LAUNCH_ARGS+=(--personality-file "$DEMO_MEMORY_DIR/personality.json")
fi
APP_NAME="Fonsters"
BUILD_DIR="$ROOT_DIR/.prototype-build"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/Fonsters.app"
cd "$ROOT_DIR"
# Stop only this task's exact prototype executable, never a different Fonsters app.
if [[ -f "$BUILD_DIR/prototype.pid" ]]; then
  TASK_PID="$(cat "$BUILD_DIR/prototype.pid")"
  if ps -p "$TASK_PID" -o command= | grep -Fq "$APP_BUNDLE/Contents/MacOS/Fonsters"; then kill "$TASK_PID" || true; fi
fi
mkdir -p "$BUILD_DIR"
xcodebuild -project Fonsters.xcodeproj -scheme Fonsters -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
  PRODUCT_BUNDLE_IDENTIFIER=com.nathanfennel.Fonsters.Playroom \
  CODE_SIGN_ENTITLEMENTS='' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO \
  build > "$BUILD_DIR/build.log" 2>&1 || { tail -80 "$BUILD_DIR/build.log"; exit 1; }
echo "Built: $APP_BUNDLE"
open_app() {
  /usr/bin/open -n "$APP_BUNDLE" --args --prototype "${LAUNCH_ARGS[@]}"
  sleep 1
  TASK_PID="$(pgrep -f "$APP_BUNDLE/Contents/MacOS/Fonsters" | head -1 || true)"
  if [[ -n "$TASK_PID" ]]; then printf '%s\n' "$TASK_PID" > "$BUILD_DIR/prototype.pid"; fi
}
case "$MODE" in
 run) open_app ;;
 --verify|verify) open_app; [[ -s "$BUILD_DIR/prototype.pid" ]]; kill -0 "$(cat "$BUILD_DIR/prototype.pid")"; echo 'PASS: native prototype process is running' ;;
 --debug|debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Fonsters" --prototype ;;
 --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate 'process == "Fonsters"' ;;
 --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.nathanfennel.Fonsters.Playroom"' ;;
 *) echo 'Usage: script/build_and_run.sh [run|--verify|--debug|--logs|--telemetry]' >&2; exit 2 ;;
esac
