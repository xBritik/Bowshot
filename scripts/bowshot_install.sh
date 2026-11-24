#!/bin/bash
# SPDX-License-Identifier: MIT
# Puts the game app the build made into the Applications folder. On the same APFS volume the copy is a clone (cp -c): it takes no extra space and no time, and the app
# stays where the build made it too, so the next build can reuse it (dm/mac/pack_app.py keeps its key beside it).
# Usage: bowshot_install.sh <built app> [<install folder>]      (default /Applications; BOWSHOT_INSTALL_DIR names another, for tests)
# Prints INSTALLED: <path> when done, or NOTE: <why not>, and exits 0 either way: the app is good where the build made it. An app of the same name is replaced only when it is
# a Bowshot game app of the same title (same DMTitleID) and is not running; anything else is left alone.
set -euo pipefail
APP="${1:?Usage: bowshot_install.sh <built app> [<install folder>]}"
DIR="${2:-${BOWSHOT_INSTALL_DIR:-/Applications}}"
NAME="$(basename "$APP")"
DEST="$DIR/$NAME"
plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true; }

[[ -d "$APP" ]] || { echo "NOTE: The built app is missing: $APP"; exit 0; }
[[ -d "$DIR" && -w "$DIR" ]] || { echo "NOTE: $DIR cannot be written, so the app stays in $(dirname "$APP")."; exit 0; }
if [[ -e "$DEST" ]]; then
  OLD="$(plist "$DEST" DMTitleID)"; NEW="$(plist "$APP" DMTitleID)"
  [[ -n "$OLD" && "$OLD" == "$NEW" ]] || { echo "NOTE: $DEST exists and is not a Bowshot game app of this title, so it is left alone; the new app stays in $(dirname "$APP")."; exit 0; }
  if pgrep -f "$DEST/Contents/MacOS/" >/dev/null 2>&1; then echo "NOTE: The game in $DIR is running. Quit it and build again to replace it; the new app stays in $(dirname "$APP")."; exit 0; fi
fi
if [[ "$(stat -f %d "$APP")" != "$(stat -f %d "$DIR")" ]]; then   # not the same volume: a real copy
  NEED_KB="$(du -sk "$APP" | cut -f1)"; FREE_KB="$(df -k "$DIR" | awk 'NR==2 {print $4}')"
  (( FREE_KB > NEED_KB + 5 * 1024 * 1024 )) || { echo "NOTE: $DIR has not enough free space for a copy of the app ($(( NEED_KB / 1048576 )) GB), so it stays in $(dirname "$APP")."; exit 0; }
fi
TMP="$DIR/.$NAME.installing"
trap 'rm -rf "$TMP"' EXIT
rm -rf "$TMP"
/bin/cp -cR "$APP" "$TMP"
rm -rf "$DEST"
mv "$TMP" "$DEST"
echo "INSTALLED: $DEST"
