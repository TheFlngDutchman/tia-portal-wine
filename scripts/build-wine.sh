#!/usr/bin/env bash
# Build a complete Wine from the source that matches the installed Wine version,
# with all patches in patches/wine applied. Needed for patches to Wine's
# Unix-side libraries (ntdll.so, mountmgr), which cannot be replaced per prefix
# the way scripts/build-wine-patches.sh replaces individual DLLs.
#
# The result runs from the build tree: $TIAWINE_ROOT/wine-build/wine
# Needs: git, gcc, make, flex, bison, mingw-w64-gcc and Wine's build dependencies.
set -euo pipefail
. "$(dirname "$0")/env.sh"
repo="$(cd "$(dirname "$0")/.." && pwd)"
tag="wine-$(/usr/bin/wine --version | sed 's/^wine-//; s/ .*//')"
src="$TIAWINE_ROOT/wine-src"; build="$TIAWINE_ROOT/wine-build"
[ -d "$src" ] || git clone --depth 1 --branch "$tag" https://gitlab.winehq.org/wine/wine.git "$src"
for p in "$repo"/patches/wine/*.patch; do
  git -C "$src" apply --reverse --check "$p" 2>/dev/null || git -C "$src" apply "$p"
done
mkdir -p "$build" && cd "$build"
[ -f Makefile ] || "$src/configure" --enable-archs=i386,x86_64 --disable-tests
make -j"$(nproc)"
mkdir -p "$TIAWINE_ROOT/wine-bin"
ln -sfn "$build/wine" "$TIAWINE_ROOT/wine-bin/wine"
ln -sfn "$build/server/wineserver" "$TIAWINE_ROOT/wine-bin/wineserver"
echo "custom wine: $build/wine  ($("$build/wine" --version))"
