#include <windows.h>
#include <winioctl.h>
#include <winternl.h>
#include <stdio.h>
int main(int argc, char **argv)
{
    BY_HANDLE_FILE_INFORMATION bi; char vol[8] = "\\\\.\\X:"; BYTE out[512] = {0}; DWORD size = 0;
    STORAGE_PROPERTY_QUERY q = { StorageDeviceProperty, PropertyStandardQuery };
    STORAGE_DEVICE_DESCRIPTOR *d = (STORAGE_DEVICE_DESCRIPTOR *)out; DISK_GEOMETRY g; ULONG len = 0; BYTE name[1024];
    HANDLE f = CreateFileA(argv[1], GENERIC_READ, 3, NULL, OPEN_EXISTING, 0, NULL), v;
    if (f == INVALID_HANDLE_VALUE) return 1;
    GetFileInformationByHandle(f, &bi);
    printf("file index 0x%08lx%08lx, attributes 0x%08lx, links %lu\n", bi.nFileIndexHigh, bi.nFileIndexLow, bi.dwFileAttributes, bi.nNumberOfLinks);
    printf("created %llu, modified %llu\n", ((ULONGLONG)bi.ftCreationTime.dwHighDateTime << 32) | bi.ftCreationTime.dwLowDateTime, ((ULONGLONG)bi.ftLastWriteTime.dwHighDateTime << 32) | bi.ftLastWriteTime.dwLowDateTime);
    if (!NtQueryObject(f, ObjectNameInformation, name, sizeof(name), &len)) printf("object name: %ls\n", ((UNICODE_STRING *)name)->Buffer);
    vol[4] = argv[1][0];
    v = CreateFileA(vol, 0, 3, NULL, OPEN_EXISTING, 0, NULL);
    if (v == INVALID_HANDLE_VALUE) { printf("volume open failed %lu\n", GetLastError()); return 0; }
    if (DeviceIoControl(v, IOCTL_STORAGE_QUERY_PROPERTY, &q, sizeof(q), out, sizeof(out), &size, NULL))
        printf("storage: bus type %d, removable %d, device type %d, vendor '%s', product '%s', serial '%s'\n", d->BusType, d->RemovableMedia, d->DeviceType,
               d->VendorIdOffset ? (char *)out + d->VendorIdOffset : "", d->ProductIdOffset ? (char *)out + d->ProductIdOffset : "", d->SerialNumberOffset ? "<present>" : "");
    else printf("IOCTL_STORAGE_QUERY_PROPERTY failed %lu\n", GetLastError());
    if (DeviceIoControl(v, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 0, &g, sizeof(g), &size, NULL))
        printf("geometry: media type %d, cylinders %lld, tracks/cyl %lu, sectors/track %lu, bytes/sector %lu\n", g.MediaType, g.Cylinders.QuadPart, g.TracksPerCylinder, g.SectorsPerTrack, g.BytesPerSector);
    else printf("IOCTL_DISK_GET_DRIVE_GEOMETRY failed %lu\n", GetLastError());
    return 0;
}
