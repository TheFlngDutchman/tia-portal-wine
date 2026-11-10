#!/usr/bin/env bash
# Attach and mount the ext4 image that holds the Wine prefix (no root needed).
# The image exists because exFAT cannot store symlinks or Unix permissions,
# both of which a Wine prefix requires.
set -euo pipefail
. "$(dirname "$0")/env.sh"
if findmnt -n "$TIAWINE_ROOT" >/dev/null; then echo "already mounted: $TIAWINE_ROOT"; exit 0; fi
if [ ! -e "$TIAWINE_IMG" ]; then
  size="${1:-200G}"
  echo "creating $TIAWINE_IMG ($size)"
  mkdir -p "$(dirname "$TIAWINE_IMG")"
  truncate -s "$size" "$TIAWINE_IMG"
  mkfs.ext4 -q -L TIAWINE -m 0 -E "root_owner=$(id -u):$(id -g)" "$TIAWINE_IMG"
fi
loop=$(udisksctl loop-setup -f "$TIAWINE_IMG" | grep -o '/dev/loop[0-9]*')
findmnt -n "$TIAWINE_ROOT" >/dev/null || udisksctl mount -b "$loop"
findmnt "$TIAWINE_ROOT"
