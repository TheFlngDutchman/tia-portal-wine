/* Print a volume's serial number and where a file's data lies on it, as
 * Windows programs see them (GetVolumeInformation, FSCTL_GET_RETRIEVAL_POINTERS).
 * Compare with tools/ntfs_probe.py, which reads the same from the raw volume.
 *
 * Build: x86_64-w64-mingw32-gcc -O2 -o retrieval_pointers.exe retrieval_pointers.c
 * Run:   wine retrieval_pointers.exe <file> [--show]
 */
#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <string.h>

int main( int argc, char **argv )
{
    union { RETRIEVAL_POINTERS_BUFFER rp; BYTE raw[1024]; } out;
    STARTING_VCN_INPUT_BUFFER in = {{{0}}};
    char root[4] = "X:\\", fs[32] = "";
    DWORD serial = 0, size = 0, i;
    BOOL show = argc > 2 && !strcmp( argv[2], "--show" );
    HANDLE file;

    if (argc < 2) return 2;
    root[0] = argv[1][0];
    if (!GetVolumeInformationA( root, NULL, 0, &serial, NULL, NULL, fs, sizeof(fs) ))
        printf( "GetVolumeInformation failed: %lu\n", GetLastError() );
    else if (show) printf( "volume %s: file system %s, serial %04lX-%04lX\n", root, fs, serial >> 16, serial & 0xffff );
    else printf( "volume %s: file system %s, serial %s\n", root, fs, serial ? "<non-zero>" : "0" );

    file = CreateFileA( argv[1], GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL );
    if (file == INVALID_HANDLE_VALUE) { printf( "open failed: %lu\n", GetLastError() ); return 1; }
    if (!DeviceIoControl( file, FSCTL_GET_RETRIEVAL_POINTERS, &in, sizeof(in), &out, sizeof(out), &size, NULL ))
    {
        printf( "FSCTL_GET_RETRIEVAL_POINTERS failed: %lu\n", GetLastError() );
        return 1;
    }
    printf( "extents: %lu, starting VCN %lld\n", out.rp.ExtentCount, out.rp.StartingVcn.QuadPart );
    for (i = 0; i < out.rp.ExtentCount; i++)
        printf( "  next VCN %lld, LCN %lld\n", out.rp.Extents[i].NextVcn.QuadPart, out.rp.Extents[i].Lcn.QuadPart );
    return 0;
}
