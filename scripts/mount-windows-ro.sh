#!/usr/bin/env bash
# Mount the existing Windows installation READ-ONLY so an installed TIA Portal
# can be inspected. Nothing is ever written to the Windows partition.
set -euo pipefail
. "$(dirname "$0")/env.sh"
if findmnt -n "$TIAWINE_WIN" >/dev/null; then echo "already mounted: $TIAWINE_WIN"; exit 0; fi
pkexec bash -c "mkdir -p '$TIAWINE_WIN' && mount -t ntfs3 -o ro,uid=$(id -u),gid=$(id -g),fmask=0133,dmask=0022 '$TIAWINE_WINDEV' '$TIAWINE_WIN'"
findmnt "$TIAWINE_WIN"
