#!/usr/bin/env bash
# Build the patched Wine DLLs in patches/wine (32- and 64-bit) from the Wine
# source that matches the installed Wine, and install them into the project prefix.
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
make -j"$(nproc)" dlls/wbemprox/x86_64-windows/wbemprox.dll dlls/wbemprox/i386-windows/wbemprox.dll \
  dlls/wminet_utils/x86_64-windows/wminet_utils.dll dlls/wminet_utils/i386-windows/wminet_utils.dll \
  dlls/kernelbase/x86_64-windows/kernelbase.dll dlls/kernelbase/i386-windows/kernelbase.dll \
  dlls/ncrypt/x86_64-windows/ncrypt.dll dlls/ncrypt/i386-windows/ncrypt.dll \
  dlls/dssenh/x86_64-windows/dssenh.dll dlls/dssenh/i386-windows/dssenh.dll
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
# kernelbase: File.Exists() on a named pipe (patch 0003). If the prefix stops
# starting after this, run once with WINEDLLOVERRIDES=kernelbase=b to recover.
install_native dlls/kernelbase/x86_64-windows/kernelbase.dll "$win/system32/kernelbase.dll"
install_native dlls/kernelbase/i386-windows/kernelbase.dll "$win/syswow64/kernelbase.dll"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v kernelbase /d native,builtin /f >/dev/null
# ncrypt: ECDH keys, secret agreement and key derivation (patch 0004).
install_native dlls/ncrypt/x86_64-windows/ncrypt.dll "$win/system32/ncrypt.dll"
install_native dlls/ncrypt/i386-windows/ncrypt.dll "$win/syswow64/ncrypt.dll"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v ncrypt /d native,builtin /f >/dev/null
# dssenh: classic CryptoAPI Diffie-Hellman (patch 0006).
install_native dlls/dssenh/x86_64-windows/dssenh.dll "$win/system32/dssenh.dll"
install_native dlls/dssenh/i386-windows/dssenh.dll "$win/syswow64/dssenh.dll"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v dssenh /d native,builtin /f >/dev/null
# .NET 4.8 ships its own WMINet_Utils.dll, which wraps WMI objects and relies on
# a proxy/stub for IWbemServices that Wine does not have. Wine's wminet_utils
# passes the objects through unwrapped; the patched build (which adds functions
# TIA Portal calls) replaces Microsoft's file in the .NET directories. The
# original is kept next to it as WMINet_Utils.dll.ms-orig.
for pair in "x86_64 Framework64" "i386 Framework"; do
  set -- $pair
  dst="$win/Microsoft.NET/$2/v4.0.30319/WMINet_Utils.dll"
  [ -e "$dst.ms-orig" ] || cp "$dst" "$dst.ms-orig"
  install_native "dlls/wminet_utils/$1-windows/wminet_utils.dll" "$dst"
done
wine reg add 'HKCU\Software\Wine\DllOverrides' /v wminet_utils /d native,builtin /f >/dev/null
wineserver -k || true
echo "patched wbemprox, wminet_utils, kernelbase, ncrypt and dssenh installed into $WINEPREFIX"
