# Source this file: . scripts/env.sh
# All paths can be overridden from the environment.
export TIAWINE_IMG="${TIAWINE_IMG:-/run/media/$USER/1TB/tia-wine/tia-wine.img}"   # ext4 image file
export TIAWINE_ROOT="${TIAWINE_ROOT:-/run/media/$USER/TIAWINE}"                    # where the image mounts
export TIAWINE_WIN="${TIAWINE_WIN:-/mnt/win-ro}"                                   # read-only Windows mount
export TIAWINE_WINDEV="${TIAWINE_WINDEV:-/dev/nvme0n1p3}"                          # Windows partition
export WINEPREFIX="${WINEPREFIX:-$TIAWINE_ROOT/prefix}"
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all,+err}"
export TIAWINE_LOGS="${TIAWINE_LOGS:-$TIAWINE_ROOT/logs}"
export TIA_VERSION="${TIA_VERSION:-V21}"
# A complete patched Wine built by scripts/build-wine.sh takes precedence over
# the system Wine. It runs from its build tree.
if [ -x "$TIAWINE_ROOT/wine-bin/wine" ]; then export PATH="$TIAWINE_ROOT/wine-bin:$PATH"; fi
