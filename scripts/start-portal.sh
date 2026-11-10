#!/usr/bin/env bash
# Start TIA Portal in the project prefix and keep a log of the run.
# usage: scripts/start-portal.sh [project.apNN as a Windows path]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/env.sh"
"$here/mount-storage.sh" >/dev/null
mkdir -p "$TIAWINE_LOGS"
log="$TIAWINE_LOGS/$(date +%Y%m%d-%H%M%S)-portal.log"
echo "log: $log"
cd "$WINEPREFIX/drive_c/Program Files/Siemens/Automation/Portal $TIA_VERSION/Bin"
WINEDEBUG="${WINEDEBUG_PORTAL:-+err,fixme-all}" exec wine Siemens.Automation.Portal.exe "$@" >"$log" 2>&1
