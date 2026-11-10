#!/usr/bin/env bash
# Create the 64-bit Wine prefix and install the runtimes TIA Portal needs.
# TIA Portal V21 targets .NET Framework 4.8 (see docs/inventory.md).
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$TIAWINE_LOGS"
if [ ! -e "$WINEPREFIX/system.reg" ]; then
  WINEDLLOVERRIDES="mscoree=d;mshtml=d" wineboot -i 2>&1 | tee "$TIAWINE_LOGS/wineboot.log"
  wineserver -w
fi
winetricks -q win10 2>&1 | tee "$TIAWINE_LOGS/winetricks-win10.log"
winetricks -q dotnet48 2>&1 | tee "$TIAWINE_LOGS/winetricks-dotnet48.log"
winetricks -q corefonts vcrun2022 2>&1 | tee "$TIAWINE_LOGS/winetricks-misc.log"
wineserver -w
echo "prefix ready: $WINEPREFIX"
