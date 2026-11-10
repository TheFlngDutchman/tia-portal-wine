#!/usr/bin/env bash
# Build a patched wbemprox.dll (32- and 64-bit) from the Wine source that matches
# the installed Wine, and place it where scripts/env.sh picks it up (WINEDLLPATH).
# Needs: git, gcc, make, flex, bison, mingw-w64-gcc.
set -euo pipefail
. "$(dirname "$0")/env.sh"
repo="$(cd "$(dirname "$0")/.." && pwd)"
tag="wine-$(wine --version | sed 's/^wine-//; s/ .*//')"
src="$TIAWINE_ROOT/wine-src"; build="$TIAWINE_ROOT/wine-build"; out="$TIAWINE_ROOT/wine-dlls"
[ -d "$src" ] || git clone --depth 1 --branch "$tag" https://gitlab.winehq.org/wine/wine.git "$src"
for p in "$repo"/patches/wine/*.patch; do
  git -C "$src" apply --reverse --check "$p" 2>/dev/null || git -C "$src" apply "$p"
done
mkdir -p "$build" && cd "$build"
[ -f Makefile ] || "$src/configure" --enable-archs=i386,x86_64 --disable-tests
make -j"$(nproc)" dlls/wbemprox/x86_64-windows/wbemprox.dll dlls/wbemprox/i386-windows/wbemprox.dll
for a in x86_64 i386; do
  mkdir -p "$out/$a-windows"
  cp "dlls/wbemprox/$a-windows/wbemprox.dll" "$out/$a-windows/"
done
echo "patched DLLs in $out"
