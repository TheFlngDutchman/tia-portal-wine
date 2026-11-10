#!/usr/bin/env bash
# Stop everything running in the project prefix (Portal and the Siemens
# services). Unsaved work in Portal is lost.
set -euo pipefail
. "$(dirname "$0")/env.sh"
wineserver -k || true
echo "wine session stopped"
