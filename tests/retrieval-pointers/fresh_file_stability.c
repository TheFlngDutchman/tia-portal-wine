#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
static void report(const char *when, const char *path)
{
    union { RETRIEVAL_POINTERS_BUFFER rp; BYTE raw[256]; } out; STARTING_VCN_INPUT_BUFFER in = {{{0}}};
    BY_HANDLE_FILE_INFORMATION bi; DWORD size; BOOL ok;
    HANDLE f = CreateFileA(path, GENERIC_READ, 7, NULL, OPEN_EXISTING, 0, NULL);
    GetFileInformationByHandle(f, &bi);
    ok = DeviceIoControl(f, FSCTL_GET_RETRIEVAL_POINTERS, &in, sizeof(in), &out, sizeof(out), &size, NULL);
    printf("%-14s index %08lx%08lx attr %02lx created %08lx%08lx  ", when, bi.nFileIndexHigh, bi.nFileIndexLow, bi.dwFileAttributes,
           bi.ftCreationTime.dwHighDateTime, bi.ftCreationTime.dwLowDateTime);
    if (ok) printf("LCN %lld\n", out.rp.Extents[0].Lcn.QuadPart); else printf("retrieval pointers failed: %lu\n", GetLastError());
    CloseHandle(f);
}
int main(int argc, char **argv)
{
    char buf[2560] = {1}; DWORD n; int i;
    HANDLE f = CreateFileA(argv[1], GENERIC_READ | GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f == INVALID_HANDLE_VALUE) { printf("create failed %lu\n", GetLastError()); return 1; }
    WriteFile(f, buf, sizeof(buf), &n, NULL);
    CloseHandle(f);
    SetFileAttributesA(argv[1], FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM | FILE_ATTRIBUTE_ARCHIVE);
    report("right away:", argv[1]);
    for (i = 0; i < 4; i++) { Sleep(12000); report("12 s later:", argv[1]); }
    return 0;
}
