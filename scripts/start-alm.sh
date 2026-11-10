#!/usr/bin/env bash
# Start the Automation License Manager window in the project prefix.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/env.sh"
"$here/mount-storage.sh" >/dev/null
mkdir -p "$TIAWINE_LOGS"
log="$TIAWINE_LOGS/$(date +%Y%m%d-%H%M%S)-alm.log"
echo "log: $log"
cd "$WINEPREFIX/drive_c/Program Files/Siemens/Automation/Automation License Manager/almapp"
WINEDEBUG="${WINEDEBUG_ALM:-+err,fixme-all}" exec wine almapp64x.exe "$@" >"$log" 2>&1
