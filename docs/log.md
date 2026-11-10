# Experiment log

## 2026-11-10

- Host: Arch-based (Omarchy), kernel 7.2, Wine 11.20, winetricks 20260125.
- Storage: 200 GB ext4 image file on an exFAT drive, mounted with `udisksctl`
  (exFAT cannot hold a Wine prefix: no symlinks, no Unix permissions).
- Inspected an installed TIA Portal V21 read-only; results in `inventory.md`.
- Started creating the prefix with .NET Framework 4.8 (`scripts/create-prefix.sh`).
- Prefix created. .NET Framework 4.8 installed (registry release 528049), plus
  core fonts and the VC++ 2022 runtime. `dotnet48` left the prefix reporting
  Windows 7, so `win10` is now set again at the end of `create-prefix.sh`.
- First run of the V21 installer (`Start.exe` from the mounted ISO). The splash
  screen appears, then a dialog: "The validation mechanism of this setup detected
  that the setup files were modified."
  - Cause: the installer's integrity validator opens the signed catalog
    `Catalogs/SEBU-WINCCCA.cat` through the Windows WinTrust catalog API. Wine
    11.20 fails to parse it (`err:wintrust:CryptCATEnumerateMember Corrupted
    catalog entry?`), the validator throws `InvalidDataException: Invalid catalog
    file` and exits with code 3. This is a Wine gap, not a modified image.
  - Independent check on Linux: all 2079 files listed in
    `InstData/Resources/CRC.txt` match their SHA-256 values, and the catalog is
    signed by "Siemens AG" (DigiCert code-signing chain).
  - The dialog offers to continue. A proper fix belongs in Wine's `wintrust`.
- Second installer run, continuing past the validation dialog: `SIA2.exe` (the
  .NET setup engine, 32-bit) crashes during "START OS analyse" with
  `System.InvalidCastException` in
  `System.Management.SecuredIWbemServicesHandler.ExecQuery_`, called from
  `OsVersion.GetVistaSku()`.
  - Reproduced without Siemens code in `tests/wmi-sta`: on an STA thread the
    first WMI query works and every later one fails; on an MTA thread all work.
  - Cause: from an STA thread, System.Management opens the WMI connection on a
    worker thread in the multithreaded apartment and then uses the object from
    the STA thread. .NET asks the object for `IMarshal` and `IAgileObject`;
    Wine's `wbemprox` answers "not implemented" for both, so .NET tries to
    marshal `IWbemServices` between apartments, and Wine has no proxy/stub for
    it. On Windows these objects are free-threaded.
  - Proposed fix: `patches/wine/0001-wbemprox-mark-objects-agile.patch` makes the
    wbemprox locator, services, enumerator and class objects answer
    `IAgileObject`. `scripts/build-wbemprox.sh` builds it. **Not built or tested
    yet.**
