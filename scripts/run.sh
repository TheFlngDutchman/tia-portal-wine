#!/usr/bin/env bash
# Run a Windows program in the project prefix and keep a timestamped log.
# usage: scripts/run.sh <name-for-log> <program> [args...]
set -euo pipefail
. "$(dirname "$0")/env.sh"
name="$1"; shift
mkdir -p "$TIAWINE_LOGS"
log="$TIAWINE_LOGS/$(date +%Y%m%d-%H%M%S)-$name.log"
echo "log: $log"
wine "$@" >"$log" 2>&1 || echo "exit code $? (see log)"
tail -n 40 "$log"
