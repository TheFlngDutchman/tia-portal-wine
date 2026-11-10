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
  - Fix, two parts, both needed (`scripts/build-wine-patches.sh` applies them):
    1. `patches/wine/0001-wbemprox-mark-objects-agile.patch`: the wbemprox
       services object aggregates the free-threaded marshaler, so .NET uses it
       directly from any apartment.
    2. DLL override `wminet_utils=builtin`. Microsoft's `WMINet_Utils.dll`
       (installed with .NET 4.8) wraps the services object in its own COM object
       that is not free-threaded and needs the `IWbemServices` proxy/stub. Wine's
       builtin `wminet_utils` does not wrap.
  - Result with `tests/wmi-sta`, 4 queries per run, 32- and 64-bit:

    | wbemprox | wminet_utils | STA | MTA |
    |----------|--------------|-----|-----|
    | stock | Microsoft | 1 OK, 3 fail | 4 OK |
    | patched | Microsoft | 1 OK, 3 fail | 4 OK |
    | stock | Wine builtin | 1 OK, 3 fail | 4 OK |
    | patched | Wine builtin | 4 OK | 4 OK |

  - Notes: Wine 11.20 ignores a replaced builtin DLL in the prefix and did not
    pick the patched DLL up through `WINEDLLPATH` either, so it is installed as
    a native override. The `IAgileObject` part of the patch alone had no effect;
    .NET Framework looks at `IMarshal`.
- Third installer run, with the WMI fix: the wizard runs through to the
  installation phase (defaults everywhere) and starts installing packages.
  After about 20 minutes: 6.6 GB under `Program Files\Siemens`, and several
  Siemens services are running under Wine (`S7TraceService64X`, `s7oiehsx64`,
  `S7EpaSRV64x`, TIA Help Viewer service, user management `IPCSecCom`).
  - Kernel drivers fail to load, as expected, and the installer carries on:
    `dpmconv`, `vsnl2ada` and the `s7o*` drivers need `WDFLDR.SYS` (the Windows
    Driver Framework loader, which Wine does not have); one driver calls the
    unimplemented `ntoskrnl.exe.IoOpenDeviceInterfaceRegistryKey`.
  - Also seen: unimplemented `msi.dll.MsiExtractPatchXMLDataW`.
  - The Automation License Manager package stops with the dialog "Failed to
    start the service, Error:1460, Timeout." The service `almservice`
    (`almsrv64x.exe`) starts, logs "No Listen-Socket has been set!, os error
    code = 10057" to the event log, then crashes with a page fault (read of
    address 0x18). Cause not yet known; needs a winsock trace of the service in
    a fresh Wine session. TCP port 4410 on 127.0.0.1 was already in a listening
    state inside the same Wine session at that moment.
- Installer finished with exit code 1603 and "An error occurred during setup".
  Per-package result: 54 of 58 setup units complete, including `TIA_Portal_All`,
  `Step7_All`, `Step7_Safety`, `WinCC`, `WinCCUnified_ES`. Failed: `S7DOS64`
  and `CoRtHmiRTmDriver64` (kernel drivers), `LicenseManager`, `Prosave`. Five
  "SecurityControl" steps also report errors. Installed size about 15 GB.
  - Near the end, "Set PG/PC Interface" (`S7epatsx.exe /Silent`) opens its
    dialogs with an empty interface list, and the final report step calls
    `regedit /a`, which Wine's regedit rejects. Both can be dismissed.
- Automation License Manager service, traced in a fresh session:
  - Startup is slow because it waits for the COM local server
    `{2255B183-A6E6-476E-8098-283BF4C5CBC6}` ("LicenseTransfer Object",
    `ALMPANELPLUGIN.EXE`); Wine fails to marshal `IClassFactory2` for it. This
    delay is what produced the installer's "Error 1460, Timeout".
  - It then reports RUNNING, opens its listener on 127.0.0.1:4410, and crashes.
    Its two database files in `ProgramData\...\Automation License Manager\logging`
    are 0 bytes; it treats them as corrupt, tries to copy each to
    `*.backup_corrupt` without overwrite, the copy fails because that file
    already exists, a `std::filesystem::filesystem_error` is thrown, and the
    process dies with a page fault. Why the databases never get initialised
    under Wine is not known yet.
- First start of `Siemens.Automation.Portal.exe`:
  1. Aborted in `wminet_utils.dll.SetSecurity`, a stub in Wine's builtin.
     `patches/wine/0002-wminet_utils-implement-more-functions.patch` implements
     it and nine more functions; the build script now installs this build in
     place of Microsoft's `WMINet_Utils.dll` (original kept as `.ms-orig`).
  2. With that, Portal gets further and stops with
     `InvalidOperationException: Channel is not registered` in
     `IpcConnectionManager.RegisterChannel` (a .NET Remoting IPC channel),
     wrapped in a `DlcManagerInitException`. Installing `samba` for `ntlm_auth`
     removed a Wine warning but not this error. Next step: find out why the
     channel registration fails.
- Script note: with the Siemens services installed, `wineserver -w` never
  returns, because the services keep the session alive.
- "Channel is not registered", found with REA's static .NET inspection
  (`rea inspect-managed-members` on `Siemens.Automation.CommonServices.dll`,
  type `IpcConnectionManager`; no code was run or decompiled): after
  registering its .NET Remoting IPC channel, Portal verifies it with
  `File.Exists("\\.\pipe\<name>")`. On Windows that returns true for an existing
  named pipe; under Wine 11.20 it returns false.
  - Reproduced in `tests/pipe-exists`.
  - Fix: `patches/wine/0003-kernelbase-attributes-of-named-pipes.patch` makes
    `GetFileAttributesExW` succeed for an existing pipe. The patched
    `kernelbase.dll` is installed as a native override by
    `scripts/build-wine-patches.sh` (renamed from `build-wbemprox.sh`).
- Result: `Siemens.Automation.Portal.exe` starts and shows its main window
  (project view with menu bar, toolbar and project tree). No startup exception
  in three minutes. Not yet checked: rendering of all panes, opening and
  compiling a project, licensing behaviour without the licence manager.
- Portal start-up time is similar to Windows (user observation). Opening an
  existing project and creating a new one both stay on the progress dialog
  indefinitely; Portal is idle while it waits.
  - Cause: Portal's project storage runs in a helper process,
    `Siemens.Automation.ObjectFrame.FileStorage.Server.exe`. It fails at start
    with `CryptographicException: Unknown error -2146893783` (0x80090029,
    `NTE_NOT_SUPPORTED`) from `ECDiffieHellmanCng.get_Key` ->
    `CngKey.Create` -> `NCryptCreatePersistedKey`. The helper sets up an
    ECDH + AES protected link to its clients; Wine 11.20's `ncrypt` has no ECDH
    support ("Algorithm not handled"). Portal then waits for a server that never
    comes up. Source: Portal's own diagnostic report under
    `ProgramData\Siemens\Automation\Portal V21\Diagnostics`.
  - Not a product or hardware-catalog problem: it affects a new empty project
    too. The test project also uses G120C drives, and Startdrive is not part of
    the installed bundle, so that will matter once projects open at all.
  - Next: implement ECDH (create/finalize key, export/import public key, secret
    agreement, key derivation) in Wine's `ncrypt` on top of `bcrypt`, with a
    C# test using `ECDiffieHellmanCng`.
- Debugging note: attaching `winedbg` with `bt all` causes "page fault on
  execute access to FFBB11B0" lines in other processes; those are an artefact of
  the debugger, not of the application.
- ECDH in `ncrypt`: `patches/wine/0004-ncrypt-ecdh.patch` adds ECDH P-256/P-384/
  P-521 keys (create, finalize, import, export), `NCryptSecretAgreement` and
  `NCryptDeriveKey`, all forwarding to Wine's `bcrypt`. Test
  `tests/ecdh-cng` (two `ECDiffieHellmanCng` parties, SHA-512 hash KDF, as the
  storage helper uses it): all four cases failed with `NTE_NOT_SUPPORTED`
  before the patch and pass after it. Both parties run under Wine, so this
  shows the calls work and agree with each other, not that the derived bytes
  match Windows.
