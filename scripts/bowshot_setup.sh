#!/bin/bash
# SPDX-License-Identifier: MIT
# The tools the builder needs, checked and installed from the builder window (no Terminal, no Homebrew, no administrator password except to select Xcode).
#   bowshot_setup.sh --status          one line per tool: <id>|<state>|<what to tell the player>   (state: ok, missing, manual, select, firstlaunch)
#   bowshot_setup.sh --install tools   uv, zstd and glslangValidator into "$SUPPORT_DIR/tools/bin" (pinned versions, SHA-256 checked)
#   bowshot_setup.sh --install metal   Apple's Metal Toolchain (xcodebuild -downloadComponent MetalToolchain)
#   bowshot_setup.sh --select-xcode    point the command line tools at Xcode (macOS asks for the password)
# Ids: xcode, metal, uv, zstd, glslang. bowshot_build.sh puts the tools folder first on its PATH.
set -uo pipefail
SUPPORT_DIR="${BOWSHOT_SUPPORT_DIR:-$HOME/Library/Application Support/Bowshot}"
TOOLS="$SUPPORT_DIR/tools"; BIN="$TOOLS/bin"
export PATH="$BIN:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
REQUIRED_XCODE=27.2

# Pinned downloads: the version and the SHA-256 of the archive (checked before anything is unpacked)
UV_VERSION=0.13.9
UV_URL="https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-aarch64-apple-darwin.tar.gz"
UV_SHA=5aeca67f2283f75235de40d0bd9c0a5bbc5fce23b6d48b3bf9fa1b2db08382ca
GLSLANG_VERSION=16.6.0
GLSLANG_URL="https://github.com/KhronosGroup/glslang/releases/download/$GLSLANG_VERSION/glslang-$GLSLANG_VERSION-macos-universal-release.tar.gz"
GLSLANG_SHA=4f8c05f2888a73ed0b7b274bc524af9130e09ae94b43c0f3f9ed83cfae852834
ZSTD_VERSION=1.5.7
ZSTD_URL="https://github.com/facebook/zstd/releases/download/v$ZSTD_VERSION/zstd-$ZSTD_VERSION.tar.gz"   # no macOS binary is published: it is built here from the source (a few seconds, with Xcode's compiler)
ZSTD_SHA=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3

xcode_state() {
  if xcodebuild -version >/tmp/bowshot-xcode.$$ 2>&1; then
    local v; v="$(awk '/^Xcode/ {print $2; exit}' /tmp/bowshot-xcode.$$)"; rm -f /tmp/bowshot-xcode.$$
    if [[ -n "$v" && "$(printf '%s\n%s\n' "$REQUIRED_XCODE" "$v" | sort -V | head -n 1)" != "$REQUIRED_XCODE" ]]; then
      echo "xcode|manual|Xcode $v is installed, Bowshot needs Xcode $REQUIRED_XCODE or later. Update it in the App Store."; return
    fi
    if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
      echo "xcode|firstlaunch|Open Xcode once, accept the licence and let it finish its setup, then close it."; return
    fi
    echo "xcode|ok|Xcode ${v:-?}"; return
  fi
  rm -f /tmp/bowshot-xcode.$$
  if compgen -G "/Applications/Xcode*.app" >/dev/null; then
    echo "xcode|select|Xcode is installed but not selected for the command line tools."
  else
    echo "xcode|manual|Install Xcode $REQUIRED_XCODE from the App Store (a very large download), then open it once."
  fi
}

metal_state() {
  # xcrun with no developer folder at all would offer to install the command line tools: only ask it when one is selected
  if ! xcode-select -p >/dev/null 2>&1; then echo "metal|missing|Apple's Metal Toolchain is not installed (needs Xcode first)."
  elif xcrun -sdk macosx metal --version >/dev/null 2>&1; then echo "metal|ok|Metal Toolchain"
  else echo "metal|missing|Apple's Metal Toolchain is not installed (a download of a few GB, needs Xcode first)."; fi
}

tool_state() {   # id, executable, label
  if [[ -x "$BIN/$2" ]] || command -v "$2" >/dev/null 2>&1; then echo "$1|ok|$3"
  else echo "$1|missing|$3 is not installed."; fi
}

status() {
  xcode_state; metal_state
  tool_state uv uv "uv (Python manager)"; tool_state zstd zstd "zstd (compression)"; tool_state glslang glslangValidator "glslang (shader checker)"
}

fetch() {   # url sha256 destination
  echo "Downloading $(basename "$1") …"
  curl -fL --retry 3 --progress-bar -o "$3" "$1" || { echo "ERROR: Download failed: $1"; return 1; }
  local got; got="$(shasum -a 256 "$3" | cut -d ' ' -f 1)"
  [[ "$got" == "$2" ]] || { echo "ERROR: The download does not match its expected SHA-256 ($1). It was not installed."; rm -f "$3"; return 1; }
}

sign_if_needed() {   # a binary the kernel refuses to run unsigned on Apple silicon gets an ad-hoc signature
  codesign --verify "$1" >/dev/null 2>&1 || codesign --force --sign - "$1" >/dev/null 2>&1
}

install_tools() {
  mkdir -p "$BIN"
  work="$(mktemp -d "${TMPDIR:-/tmp}/bowshot-setup.XXXXXX")"; trap 'rm -rf "$work"' EXIT
  [[ "$(uname -m)" == arm64 ]] || { echo 'ERROR: Apple silicon is required.'; return 1; }
  if [[ ! -x "$BIN/uv" ]] && ! command -v uv >/dev/null 2>&1; then
    fetch "$UV_URL" "$UV_SHA" "$work/uv.tar.gz" || return 1
    tar xzf "$work/uv.tar.gz" -C "$work" && install -m 755 "$work/uv-aarch64-apple-darwin/uv" "$BIN/uv" && sign_if_needed "$BIN/uv" || { echo 'ERROR: Could not install uv.'; return 1; }
    echo "✓ uv $UV_VERSION"
  fi
  if [[ ! -x "$BIN/glslangValidator" ]] && ! command -v glslangValidator >/dev/null 2>&1; then
    fetch "$GLSLANG_URL" "$GLSLANG_SHA" "$work/glslang.tar.gz" || return 1
    tar xzf "$work/glslang.tar.gz" -C "$work" bin/glslangValidator && install -m 755 "$work/bin/glslangValidator" "$BIN/glslangValidator" && sign_if_needed "$BIN/glslangValidator" || { echo 'ERROR: Could not install glslangValidator.'; return 1; }
    echo "✓ glslang $GLSLANG_VERSION"
  fi
  if [[ ! -x "$BIN/zstd" ]] && ! command -v zstd >/dev/null 2>&1; then
    xcrun --find clang >/dev/null 2>&1 || { echo 'ERROR: Xcode must be installed and selected before zstd can be built.'; return 1; }
    fetch "$ZSTD_URL" "$ZSTD_SHA" "$work/zstd.tar.gz" || return 1
    tar xzf "$work/zstd.tar.gz" -C "$work" || { echo 'ERROR: Could not unpack zstd.'; return 1; }
    echo "Building zstd $ZSTD_VERSION …"
    make -C "$work/zstd-$ZSTD_VERSION/programs" -j"$(sysctl -n hw.ncpu)" zstd >"$work/zstd-build.log" 2>&1 \
      || { tail -20 "$work/zstd-build.log"; echo 'ERROR: Could not build zstd.'; return 1; }
    install -m 755 "$work/zstd-$ZSTD_VERSION/programs/zstd" "$BIN/zstd" && sign_if_needed "$BIN/zstd" || { echo 'ERROR: Could not install zstd.'; return 1; }
    echo "✓ zstd $ZSTD_VERSION"
  fi
  for t in uv zstd glslangValidator; do
    command -v "$t" >/dev/null 2>&1 && "$t" --version >/dev/null 2>&1 || { echo "ERROR: $t was installed but does not run."; return 1; }
  done
  echo 'Build tools ready.'
}

install_metal() {
  xcodebuild -version >/dev/null 2>&1 || { echo 'ERROR: Install and select Xcode first.'; return 1; }
  echo 'Downloading the Metal Toolchain (a few GB) …'
  xcodebuild -downloadComponent MetalToolchain || { echo 'ERROR: The Metal Toolchain download failed. Open Xcode, then Settings, Components, and install it there.'; return 1; }
  echo 'Metal Toolchain ready.'
}

select_xcode() {
  local app; app="$(compgen -G '/Applications/Xcode*.app' | sort -V | tail -n 1)"
  [[ -n "$app" ]] || { echo 'ERROR: No Xcode found in Applications.'; return 1; }
  /usr/bin/osascript -e "do shell script \"/usr/bin/xcode-select -s '$app/Contents/Developer'\" with administrator privileges" \
    && echo "✓ Selected $app" || { echo 'ERROR: Xcode was not selected (the password prompt was cancelled?).'; return 1; }
}

case "${1:-}" in
  --status) status ;;
  --install)
    case "${2:-}" in
      tools) install_tools ;;
      metal) install_metal ;;
      *) echo 'Usage: bowshot_setup.sh --install tools|metal'; exit 2 ;;
    esac ;;
  --select-xcode) select_xcode ;;
  *) echo 'Usage: bowshot_setup.sh --status | --install tools|metal | --select-xcode'; exit 2 ;;
esac
