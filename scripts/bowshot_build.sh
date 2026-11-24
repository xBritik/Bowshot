#!/bin/bash
# SPDX-License-Identifier: MIT
# Builds only from the player's files. No game data belongs in this repository.
# The engine's progress: lines for a terminal, json events with BOWSHOT_PROGRESS=json (the builder window's progress bar; build.log then holds those events).
# A blocking error is one line that starts with ERROR: (the builder window shows it in red); the finished app is the line READY: <path> (green).
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUPPORT_DIR="${BOWSHOT_SUPPORT_DIR:-$HOME/Library/Application Support/Bowshot}"
# The tools the builder's setup screen installs (scripts/bowshot_setup.sh) come first, then Homebrew's for a Mac that has them already
export PATH="$SUPPORT_DIR/tools/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

doctor() {
  [[ "$(uname -m)" == arm64 ]] || { echo 'ERROR: Apple silicon is required.'; return 1; }
  (( $(sysctl -n hw.memsize) / 1073741824 >= 16 )) || { echo 'ERROR: This Mac has less than 16 GB of memory. The game needs 13 to 16 GB while it runs, so Bowshot cannot build it here.'; return 1; }
  uv --version >/dev/null 2>&1 || { echo 'ERROR: A build tool is missing or does not start (uv). Open the builder window and use its setup steps (Install build tools).'; return 1; }
  xcrun --find metal >/dev/null 2>&1 || { echo 'ERROR: Install Xcode 27.2 and its Metal Toolchain: the builder window has the setup steps.'; return 1; }
  for tool in zstd glslangValidator; do   # xcodegen is only for iOS builds: the builder makes a Mac app
    "$tool" --version >/dev/null 2>&1 || { echo "ERROR: Missing build tool, or it does not start: $tool. Open the builder window and use its setup steps (Install build tools)."; return 1; }
  done
}

case "${1:-}" in
  --doctor) doctor; echo 'Prerequisite executables found. Engine build performs the exact compiler-version check.'; exit 0 ;;
  --forecast) shift; exec /usr/bin/python3 "$SOURCE_ROOT/scripts/bowshot_forecast.py" "${1:?Choose a game folder}" ;;   # read-only: what the next build reuses (the Game screen)
  --build) shift ;;
  *) echo 'Usage: bowshot_build.sh --doctor | --forecast <game-folder> | --build <game-folder>'; exit 2 ;;
esac
GAME_DIR="${1:?Choose a folder containing your own game dump}"
[[ -d "$GAME_DIR" ]] || { echo 'ERROR: The game folder does not exist.'; exit 2; }
GAME_DIR="$(cd "$GAME_DIR" && pwd -P)"
if git -C "$GAME_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo 'ERROR: Choose a game folder outside a Git repository. Private game outputs must stay separate from source.'
  exit 2
fi
case "$GAME_DIR/" in "$SOURCE_ROOT/"*) echo 'ERROR: Keep game files outside the builder source.'; exit 2;; esac
doctor
mkdir -p "$SUPPORT_DIR"
REVISION="$(tr -d '\r\n' < "$SOURCE_ROOT/UPSTREAM-REVISION")"
# One writable copy per revision and version: a test build (0.1.2-beta-2) with changed engine files must not run the copy of the one before
ENGINE_DIR="$SUPPORT_DIR/engine/$REVISION-$(tr -d '\r\n' < "$SOURCE_ROOT/VERSION")"
if [[ ! -f "$ENGINE_DIR/.copy-complete" ]]; then
  echo 'Preparing a writable copy of the included engine; the signed app remains unchanged.'
  mkdir -p "$ENGINE_DIR"
  /usr/bin/python3 "$SOURCE_ROOT/tools/copy_engine.py" "$SOURCE_ROOT" "$ENGINE_DIR"
  touch "$ENGINE_DIR/.copy-complete"
fi
PYTHON="$SUPPORT_DIR/venv/bin/python3"

# Frees the disk space of files this build will not use, and only those that Bowshot made and nothing reads any more:
#   - the engine copies of other Bowshot versions or engine revisions (each build makes its own, in $SUPPORT_DIR/engine/<revision>-<version>; a copy another running build holds is kept);
#   - the engine's "obsolete" folder in the build folder (what the build retired: it is deleted by the next build anyway, and it says deleting it early costs nothing);
#   - the idle build folders Metal's pipeline archive compiler leaves in the user cache folder (scripts/clean_metal_cache.py: only folders nothing changed in for an hour, none while a game host runs).
# It never touches what the next build reuses (the extracted game, the shaders, the app), your game files, other apps, or other versions' builders. A failure here never stops the build.
FREED_KB=0
size_kb() { du -sk "$1" 2>/dev/null | cut -f1 || true; }
free_dir() { local kb; kb="$(size_kb "$1")"; if rm -rf "$1" 2>/dev/null; then FREED_KB=$(( FREED_KB + ${kb:-0} )); return 0; fi; return 1; }
human_kb() { awk -v k="$1" 'BEGIN { if (k >= 1048576) printf "%.1f GB", k / 1048576; else printf "%.0f MB", k / 1024 }'; }
tidy_engines() {
  local d pid kb before=$FREED_KB
  for d in "$SUPPORT_DIR"/engine/*; do
    [[ -d "$d" && ! -L "$d" && "$d" != "$ENGINE_DIR" && -f "$d/.copy-complete" ]] || continue   # only copies this script made
    pid="$(cat "$d/.in-use" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then continue; fi   # another build is running from it
    free_dir "$d" || echo "[RED] Could not remove the old engine copy $d"
  done
  (( FREED_KB > before )) && echo "Freed $(human_kb $(( FREED_KB - before ))): engine copies of other Bowshot versions."
  return 0
}
tidy_metal() {
  local out n bytes kb
  out="$("$PYTHON" -c 'import sys; sys.path.insert(0, sys.argv[1]); import clean_metal_cache as c; n, size, kept, bad = c.clean(); print(n, size)' "$ENGINE_DIR/scripts" 2>/dev/null)" || return 0
  read -r n bytes <<<"$out"
  [[ "${n:-0}" =~ ^[0-9]+$ && "${bytes:-0}" =~ ^[0-9]+$ ]] || return 0
  if (( bytes > 0 )); then kb=$(( bytes / 1024 )); FREED_KB=$(( FREED_KB + kb )); echo "Freed $(human_kb "$kb"): $n idle Metal build folders left in the user cache folder."; fi
  return 0
}
tidy_obsolete() {
  local kb
  [[ -d "$WORK_DIR/obsolete" ]] || return 0
  kb="$(size_kb "$WORK_DIR/obsolete")"
  if free_dir "$WORK_DIR/obsolete" && (( ${kb:-0} > 0 )); then echo "Freed $(human_kb "${kb:-0}"): what this build no longer uses (obsolete folder)."; fi
  return 0
}
# This build holds its engine copy, so a build of another Bowshot version running at the same time does not remove it
echo $$ > "$ENGINE_DIR/.in-use"; trap 'rm -f "$ENGINE_DIR/.in-use"' EXIT
if [[ ! -x "$PYTHON" ]]; then uv venv --python 3.14 --managed-python "$SUPPORT_DIR/venv"; fi
REQUIREMENTS_KEY="$(shasum -a 256 "$ENGINE_DIR/requirements-builder.txt" | cut -d ' ' -f 1)"
if [[ ! -f "$SUPPORT_DIR/requirements.key" ]] || [[ "$(cat "$SUPPORT_DIR/requirements.key")" != "$REQUIREMENTS_KEY" ]]; then
  uv pip install --python "$PYTHON" -r "$ENGINE_DIR/requirements-builder.txt"
  printf '%s\n' "$REQUIREMENTS_KEY" > "$SUPPORT_DIR/requirements.key"
fi
PRIVATE_DIR="$GAME_DIR/Bowshot-build"
# Before 0.1.3 the folder was called Bowshot-local: the same folder under its new name (a rename on one disk, at once), so the earlier build's work is kept
if [[ -d "$GAME_DIR/Bowshot-local" && ! -e "$PRIVATE_DIR" ]]; then
  mv "$GAME_DIR/Bowshot-local" "$PRIVATE_DIR" && echo 'The folder Bowshot-local is now called Bowshot-build; what it held is kept.' || { echo 'ERROR: Could not rename Bowshot-local to Bowshot-build in the game folder.'; exit 1; }
fi
WORK_DIR="$PRIVATE_DIR/build"
OUTPUT_APP="$PRIVATE_DIR/Ocarina of Time.app"   # the name Finder and Launchpad show; the menu bar shows the profile's name
mkdir -p "$PRIVATE_DIR"
BUILD_LOG="$PRIVATE_DIR/build.log"
tidy_engines; tidy_metal   # before the long work: what earlier builds left and this one will not use
printf 'Private outputs: %s\nEngine revision: %s\n' "$PRIVATE_DIR" "$REVISION"
cd "$ENGINE_DIR"
"$PYTHON" scripts/build_ipa_from_nsp.py "$GAME_DIR" --platform mac --no-run-prebuild --work-dir "$WORK_DIR" --keep-extracted --progress "${BOWSHOT_PROGRESS:-lines}" 2>&1 | tee "$BUILD_LOG"
# The second part (the game app) is one step of its own in the builder window: the engine numbers its stages afresh
if [[ "${BOWSHOT_PROGRESS:-}" == json ]]; then echo '{"ev": "bowshot_part", "name": "Game app"}'; fi
ENV_FILE="$PRIVATE_DIR/runtime.env"
printf '# Local settings for the app built from your dump\n' > "$ENV_FILE"
if grep -q 'game profile: 0400486024DEC000' "$BUILD_LOG"; then
  IMAGE="$WORK_DIR/extract/v131072/RomFS.img"
  [[ -f "$IMAGE" ]] || { echo 'ERROR: The supported Ocarina of Time v131072 RomFS image was not found.'; exit 1; }
  # Fixed for every run (the settings window does not draw a row its env file fixes). Frame rate, Display mode, Game's upscaler, Dynamic resolution and Hold frames when late
  # stay the player's: their defaults are the profile's (60 fps, a window, MetalFX, both off)
  cat >> "$ENV_FILE" <<'SETTINGS'
DM_OPMODE=0
DM_TEX_RELEASE=0
DM_GUEST_FILE=0
DM_FOCUS_KEEP=1
DM_PRESENT_INTERVAL=display
DM_PRESENT_UPSCALE=off
SETTINGS
  # The game's memory watchdog closes it when its resident memory passes this many GB (a guard against a runaway taking the whole Mac down).
  # The game itself needs 13 to 16 GB, with load peaks of about 1 GB: 2 GB are left to macOS, between 8 and 48 GB (a fixed 13 closed the game early on a Mac with more memory)
  RAM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 )); MEM_CAP=$(( RAM_GB - 2 )); (( RAM_GB <= 16 )) && MEM_CAP=$(( RAM_GB - 1 )); (( MEM_CAP < 8 )) && MEM_CAP=8; (( MEM_CAP > 48 )) && MEM_CAP=48
  echo "DM_MEM_CAP_GB=$MEM_CAP" >> "$ENV_FILE"
  echo "Memory limit for the game: $MEM_CAP GB (this Mac has $RAM_GB GB)."
fi
"$PYTHON" scripts/build_ipa_from_nsp.py "$GAME_DIR" --platform mac-app --work-dir "$WORK_DIR" --keep-extracted --env-file "$ENV_FILE" --fallback-icon "$ENGINE_DIR/launcher/mac/AppIcon.png" -o "$OUTPUT_APP" --progress "${BOWSHOT_PROGRESS:-lines}" 2>&1 | tee -a "$BUILD_LOG"
# The game app goes into Applications too (a clone on the same volume: no extra space; scripts/bowshot_install.sh says why when it cannot). The one in Bowshot-build stays, so the next build reuses it
INSTALL_OUT="$(bash "$SOURCE_ROOT/scripts/bowshot_install.sh" "$OUTPUT_APP" 2>&1)" || INSTALL_OUT="NOTE: The install in Applications failed, so the app stays in $PRIVATE_DIR."
printf '%s\n' "$INSTALL_OUT" | tee -a "$BUILD_LOG"
FINAL_APP="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^INSTALLED: //p' | tail -1)"
# What this build did and how long each step took, kept beside it (scripts/bowshot_report.py; docs/builds/README.md compares builds). A failure here never stops the build
REPORT_NOTE=""; if "$PYTHON" "$ENGINE_DIR/scripts/bowshot_report.py" report "$BUILD_LOG" --out "$PRIVATE_DIR/build-report.md" >/dev/null 2>&1; then REPORT_NOTE="Build report: $PRIVATE_DIR/build-report.md"; fi
tidy_obsolete; tidy_metal   # the build succeeded: what it retired, and the Metal folders its pipeline steps left (no host of this build runs any more)
if (( FREED_KB > 0 )); then echo "FREED: $(human_kb "$FREED_KB") of files this build did not use."; fi
[[ -z "$REPORT_NOTE" ]] || echo "$REPORT_NOTE"
printf 'version=%s\nrevision=%s\n' "$(tr -d '\r\n' < "$SOURCE_ROOT/VERSION")" "$REVISION" > "$PRIVATE_DIR/last-build.txt"   # read by --forecast: what this build was made with
printf '\nREADY: %s\nThis app contains your game. Keep it private; do not upload it.\n' "${FINAL_APP:-$OUTPUT_APP}"
