#!/usr/bin/env bash
# Build a patched wbemprox.dll (32- and 64-bit) from the Wine source that matches
# the installed Wine, and install it into the project prefix.
# Needs: git, gcc, make, flex, bison, mingw-w64-gcc.
set -euo pipefail
. "$(dirname "$0")/env.sh"
repo="$(cd "$(dirname "$0")/.." && pwd)"
tag="wine-$(wine --version | sed 's/^wine-//; s/ .*//')"
src="$TIAWINE_ROOT/wine-src"; build="$TIAWINE_ROOT/wine-build"
[ -d "$src" ] || git clone --depth 1 --branch "$tag" https://gitlab.winehq.org/wine/wine.git "$src"
for p in "$repo"/patches/wine/*.patch; do
  git -C "$src" apply --reverse --check "$p" 2>/dev/null || git -C "$src" apply "$p"
done
mkdir -p "$build" && cd "$build"
[ -f Makefile ] || "$src/configure" --enable-archs=i386,x86_64 --disable-tests
make -j"$(nproc)" dlls/wbemprox/x86_64-windows/wbemprox.dll dlls/wbemprox/i386-windows/wbemprox.dll
# Wine always loads its own builtin wbemprox from the Wine installation, even
# if the copy in the prefix is replaced. So the patched build is installed as a
# "native" DLL: the builtin marker in the DOS header is cleared and a DLL
# override makes Wine prefer it.
win="$WINEPREFIX/drive_c/windows"
install_native() {
  cp "$1" "$2"
  head -c 16 /dev/zero | dd of="$2" bs=1 seek=64 conv=notrunc status=none
}
install_native dlls/wbemprox/x86_64-windows/wbemprox.dll "$win/system32/wbem/wbemprox.dll"
install_native dlls/wbemprox/i386-windows/wbemprox.dll "$win/syswow64/wbem/wbemprox.dll"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v wbemprox /d native,builtin /f >/dev/null
# .NET 4.8 ships its own WMINet_Utils.dll, which wraps WMI objects and relies on
# a proxy/stub for IWbemServices that Wine does not have. Wine's builtin
# wminet_utils passes the objects through unwrapped.
wine reg add 'HKCU\Software\Wine\DllOverrides' /v wminet_utils /d builtin /f >/dev/null
wineserver -w
echo "patched wbemprox installed into $WINEPREFIX"
