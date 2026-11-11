#!/usr/bin/env bash
# Attach a VHD that holds Siemens licence keys and map it as a Wine drive.
# usage: scripts/mount-licence-volume.sh <file.vhd> [ro|rw] [drive letter, default g]
#
# Read-only is the default. The user gets read access to the partition's block
# device (pkexec prompt): Wine reads the NTFS serial number and file records
# from it. That access ends when the loop device is detached.
set -euo pipefail
. "$(dirname "$0")/env.sh"
vhd="$1"; mode="${2:-ro}"; letter="${3:-g}"
opt=(); [ "$mode" = ro ] && opt=(-r)
loop=$(udisksctl loop-setup "${opt[@]}" -f "$vhd" | grep -o '/dev/loop[0-9]*')
part="${loop}p1"
for _ in 1 2 3 4 5; do [ -b "$part" ] && break; sleep 1; done
udisksctl mount -b "$part" >/dev/null 2>&1 || true   # the desktop may have mounted it already
mnt=$(findmnt -no TARGET "$part" | head -n1)
pkexec setfacl -m "u:$(id -un):r" "$part"
ln -sfn "$mnt" "$WINEPREFIX/dosdevices/$letter:"
ln -sfn "$part" "$WINEPREFIX/dosdevices/$letter::"
echo "$vhd -> $part ($mode) mounted at $mnt, Wine drive ${letter^^}:"
echo "restart the Wine session (scripts/stop-wine.sh) so the drive is picked up"
