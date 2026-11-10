#!/usr/bin/env bash
# Summarise an installed TIA Portal from the read-only Windows mount:
# file counts, target runtime, and Siemens kernel drivers / services.
# Prints facts only; copies no Siemens files into the repository.
set -euo pipefail
. "$(dirname "$0")/env.sh"
P="$TIAWINE_WIN/Program Files/Siemens/Automation/Portal $TIA_VERSION"
[ -d "$P" ] || { echo "not found: $P"; exit 1; }
echo "portal dir : $P"
echo "size       : $(du -sh "$P" | cut -f1)"
echo "exe / dll  : $(find "$P" -iname '*.exe' | wc -l) / $(find "$P" -iname '*.dll' | wc -l)"
echo "main exe   : $(file -b "$P/Bin/Siemens.Automation.Portal.exe")"
echo "runtime    : $(grep -o 'sku="[^"]*"' "$P/Bin/Siemens.Automation.Portal.exe.config" || echo unknown)"
echo "kernel drivers mentioning Siemens:"
for f in "$TIAWINE_WIN"/Windows/System32/drivers/*.sys; do
  strings -el "$f" 2>/dev/null | grep -qi -m1 siemens && echo "  $(basename "$f")"
done
