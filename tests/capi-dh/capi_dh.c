/* Classic CryptoAPI Diffie-Hellman with the "Microsoft Enhanced DSS and
 * Diffie-Hellman Cryptographic Provider", the way the Automation License
 * Manager service uses it: ephemeral key with caller-supplied P and G.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -o capi_dh.exe capi_dh.c -ladvapi32
 * Run:   wine capi_dh.exe [session algorithm, hex ALG_ID, default 660c = CALG_CYLINK_MEK]
 */
#include <windows.h>
#include <wincrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 768-bit MODP group (RFC 2409, Oakley group 1), big endian; generator 2. */
static const char prime_hex[] =
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74"
    "020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437"
    "4FE1356D6D51C245E485B576625E7EC6F44C42E9A63A3620FFFFFFFFFFFFFFFF";

#define BITS  768
#define BYTES (BITS / 8)

static int fail( const char *what )
{
    printf( "FAIL: %s (error %08lx)\n", what, GetLastError() );
    return 1;
}

static BOOL make_party( HCRYPTPROV prov, const BYTE *p, const BYTE *g, HCRYPTKEY *key, BYTE *blob, DWORD *blob_len )
{
    CRYPT_DATA_BLOB data;

    if (!CryptGenKey( prov, CALG_DH_EPHEM, (BITS << 16) | CRYPT_PREGEN, key )) return FALSE;
    data.cbData = BYTES; data.pbData = (BYTE *)p;
    if (!CryptSetKeyParam( *key, KP_P, (BYTE *)&data, 0 )) return FALSE;
    data.cbData = BYTES; data.pbData = (BYTE *)g;
    if (!CryptSetKeyParam( *key, KP_G, (BYTE *)&data, 0 )) return FALSE;
    if (!CryptSetKeyParam( *key, KP_X, NULL, 0 )) return FALSE;
    return CryptExportKey( *key, 0, PUBLICKEYBLOB, 0, blob, blob_len );
}

int main( int argc, char **argv )
{
    ALG_ID alg = argc > 1 ? strtoul( argv[1], NULL, 16 ) : CALG_CYLINK_MEK;
    HCRYPTPROV prov;
    HCRYPTKEY key_a, key_b, agreed_a, agreed_b;
    BYTE p[BYTES], g[BYTES] = { 2 }, blob_a[256], blob_b[256];
    BYTE text[64], check[64];
    DWORD len_a = sizeof(blob_a), len_b = sizeof(blob_b), len, i;

    for (i = 0; i < BYTES; i++)   /* big endian hex -> little endian bytes */
    {
        unsigned int v;
        sscanf( prime_hex + 2 * (BYTES - 1 - i), "%2x", &v );
        p[i] = v;
    }

    if (!CryptAcquireContextA( &prov, NULL, MS_ENH_DSS_DH_PROV_A, PROV_DSS_DH, CRYPT_VERIFYCONTEXT ))
        return fail( "CryptAcquireContext" );
    if (!make_party( prov, p, g, &key_a, blob_a, &len_a )) return fail( "party A key" );
    if (!make_party( prov, p, g, &key_b, blob_b, &len_b )) return fail( "party B key" );
    printf( "public key blob: %lu bytes\n", len_a );

    if (!CryptImportKey( prov, blob_b, len_b, key_a, 0, &agreed_a )) return fail( "A imports B" );
    if (!CryptImportKey( prov, blob_a, len_a, key_b, 0, &agreed_b )) return fail( "B imports A" );
    if (!CryptSetKeyParam( agreed_a, KP_ALGID, (BYTE *)&alg, 0 )) return fail( "A KP_ALGID" );
    if (!CryptSetKeyParam( agreed_b, KP_ALGID, (BYTE *)&alg, 0 )) return fail( "B KP_ALGID" );

    /* A encrypts, B decrypts: only works if both derived the same key. */
    memset( text, 0, sizeof(text) );
    strcpy( (char *)text, "tia-portal-wine DH round trip" );
    memcpy( check, text, sizeof(check) );
    len = 32;
    if (!CryptEncrypt( agreed_a, 0, TRUE, 0, text, &len, sizeof(text) )) return fail( "CryptEncrypt" );
    printf( "ciphertext: %lu bytes, differs from plaintext: %s\n", len, memcmp( text, check, 32 ) ? "yes" : "no" );
    if (!CryptDecrypt( agreed_b, 0, TRUE, 0, text, &len )) return fail( "CryptDecrypt" );
    if (len != 32 || memcmp( text, check, 32 )) { printf( "FAIL: round trip mismatch\n" ); return 1; }

    printf( "OK: algorithm %04x, both parties derived the same key\n", alg );
    return 0;
}
