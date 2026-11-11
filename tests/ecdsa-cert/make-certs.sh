#!/usr/bin/env bash
# Create throw-away EC certificates plus a signed data file for EcdsaCert.cs.
# The signature is converted from DER to the fixed-size r||s form that
# Windows CNG uses.
set -euo pipefail
out="${1:-.}"
for spec in p256:prime256v1:32 p384:secp384r1:48 p521:secp521r1:66; do
  IFS=: read -r name curve size <<<"$spec"
  openssl ecparam -name "$curve" -genkey -noout -out "$out/$name.key" 2>/dev/null
  openssl req -new -x509 -key "$out/$name.key" -subj "/CN=tia-portal-wine test $name" -days 30 -outform DER -out "$out/$name.cer"
  printf 'tia-portal-wine test data for %s\n' "$name" > "$out/$name.dat"
  openssl dgst -sha256 -sign "$out/$name.key" -out "$out/$name.der" "$out/$name.dat"
  python3 - "$out/$name.der" "$out/$name.sig" "$size" <<'PY'
import sys
der = open(sys.argv[1], 'rb').read(); size = int(sys.argv[3])
pos = 2 + (der[1] & 0x7f if der[1] & 0x80 else 0)
parts = []
for _ in range(2):
    assert der[pos] == 2
    n = der[pos + 1]; pos += 2
    if n & 0x80:
        k = n & 0x7f; n = int.from_bytes(der[pos:pos + k], 'big'); pos += k
    parts.append(int.from_bytes(der[pos:pos + n], 'big').to_bytes(size, 'big')); pos += n
open(sys.argv[2], 'wb').write(b''.join(parts))
PY
  rm -f "$out/$name.key" "$out/$name.der"
done
