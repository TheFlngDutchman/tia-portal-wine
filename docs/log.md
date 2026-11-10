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
- With the ECDH patch the storage helper (`FileStorage.Server.exe`) starts and
  stays up. Creating a project then crashes Portal with
  `CultureNotFoundException: 3098 (0x0c1a) is an invalid culture identifier`
  in `PlatformUtilities.GetAvailableCultures`. Portal resolves each of the 108
  locale IDs in its `Installation/AvailableCultures` setting; Wine's locale
  data lacks two of them, 0x081a (sr-Latn-CS) and 0x0c1a (sr-Cyrl-CS), the
  locales of the former Serbia and Montenegro.
  - Fix: `patches/wine/0005-kernelbase-former-serbia-montenegro-lcids.patch`
    maps them to sr-Latn-RS / sr-Cyrl-RS in `LCIDToLocaleName`. Test in
    `tests/culture-lcid`: 2 of 108 fail before, 0 after.
  - Portal's crash-report window (`Siemens.Automation.Diagnostics.Report.exe`)
    is not readable under Wine (user observation); not looked into.
- With patches 0001-0005 (user test): creating a new project works. Opening an
  existing V21 project gets as far as Portal's product check: its GSD file is
  installed, and the "Open project" dialog lists the products the project
  uses, with SINAMICS Startdrive (V21 HF2) marked "Installation required"; it
  is not part of the STEP 7 + Safety + WinCC bundle that was installed.
  - Shortly after that dialog, Portal goes to its crash handler with
    `TiaPersistenceOpenFailedWithProductInfoException: Required project
    elements are missing`. Whether Portal on Windows survives this case is not
    known here; under Wine it ends the session.
- Automation License Manager, clean start (the stale 0-byte database files from
  the first failed start removed): the service now gets through database
  setup, scans all drive letters for licence key folders, and then aborts.
  - Cause: it asks the "Microsoft Enhanced DSS and Diffie-Hellman Cryptographic
    Provider" for an ephemeral Diffie-Hellman key,
    `CryptGenKey(CALG_DH_EPHEM, 512 bit | CRYPT_PREGEN)`. Wine 11.20's `dssenh`
    answers `unhandled algorithm 0000aa02`; the service throws a C++ exception
    inside a `noexcept` function and terminates.
  - The earlier "databases are corrupt" crash was a follow-up of this one: the
    abort happens in the middle of the first database transaction and leaves
    empty files behind, which the next start trips over.
  - What a fix needs: classic CryptoAPI Diffie-Hellman in `dssenh` (generate
    with pre-set P and G, export/import public key blobs, agreed key converted
    to a session key) and, most likely, the symmetric encrypt/decrypt entry
    points, which `dssenh` does not have at all. Wine's `bcrypt` has DH, so the
    arithmetic exists. Not started.
- `dssenh` Diffie-Hellman, first stage
  (`patches/wine/0006-dssenh-diffie-hellman.patch`): `CALG_DH_EPHEM` keys with
  `CRYPT_PREGEN`, `KP_P` / `KP_G` / `KP_X`, public key export, import of the
  peer's public key into an agreed key, `KP_ALGID`. `CPEncrypt`, `CPDecrypt`
  and `CPGetKeyParam` exist but only log and fail. Test: `tests/capi-dh`.
  - Result: on a clean start the Automation License Manager service reaches
    RUNNING, creates its databases properly (36 kB and 24 kB instead of 0
    bytes) and listens on 127.0.0.1:4410. It generates two DH keys at start and
    exports one public key; no key agreement or encryption was requested yet.
  - Start-up still takes about four minutes because of the wait for the
    `ALMPANELPLUGIN` COM server (see above).
  - The licence manager GUI (`almapp64x.exe`) crashes at start with a call
    through a null pointer; not looked into.
- Second start with the databases in place: the licence manager service is
  RUNNING again, together with Portal. Portal sitting at its start screen makes
  no Diffie-Hellman calls, so the cipher used on the link to the licence
  manager is still unknown; it will show up once something asks for a licence.
- Licence storage: the user's licence keys are on a 50 MB VHD (NTFS volume with
  an `AX NF ZZ` folder). Attached read-only with `udisksctl loop-setup -r`.
  Wine did not map it to a drive letter by itself. Not yet presented to the
  licence manager.
- Adding a PLC in Portal makes its licence client talk to the licence manager:
  both sides do the Diffie-Hellman exchange, the service converts the agreed
  key with `KP_ALGID = CALG_CYLINK_MEK` (0x660c, DES with 40 key bits) and
  calls `CryptEncrypt`. With the first-stage patch that call failed, the
  request failed, and Portal exited on an unhandled breakpoint exception
  (0x80000003).
- `dssenh`, second stage (same patch file 0006): agreed keys can be converted
  to `CALG_CYLINK_MEK` or `CALG_DES`; `CPEncrypt` / `CPDecrypt` do DES-CBC with
  PKCS#5 padding; `CPGetKeyParam` answers the basic parameters.
  `tests/capi-dh` passes for both algorithms (A encrypts, B decrypts).
  - Caveat: which bytes of the DH secret Windows uses for the session key is
    undocumented and was not checked against Windows. The implementation is
    consistent with itself, so two Wine processes can talk to each other; it
    is not known to interoperate with a licence manager running on Windows.
- With the second-stage `dssenh` patch, Portal and the licence manager complete
  their exchanges (all decrypts succeed) and Portal shows "No valid License Key
  was found" with the trial-licence offer. That is the expected answer from a
  licence manager without keys.
- Licence volume mapped as `G:` (read-only): the licence manager finds the
  `AX NF ZZ` folder and reads the key files, but still reports no valid key.
  What it asks about the volume and the key files, and what Wine 11.20 answers:

  | Query | Wine's answer |
  |-------|---------------|
  | volume serial number | `4700-0000` instead of the NTFS serial; Wine's mountmgr does not read NTFS boot sectors |
  | `FSCTL_GET_OBJECT_ID` per key file (68 calls) | an ID made up from the Linux device and inode numbers, not the file's NTFS object ID |
  | `FSCTL_GET_RETRIEVAL_POINTERS` per key file (21 calls) | the on-disk location of the file; not checked what Wine returns |
  | `IOCTL_STORAGE_QUERY_PROPERTY`, `IOCTL_DISK_GET_DRIVE_GEOMETRY` | not checked |

  So the keys appear to be tied to properties of the volume and of the files on
  it, and under Wine those properties come out different from Windows. Giving
  the user read access to the block device did not change the reported serial
  (reverted).
  - A faithful fix would make Wine report the real values of the mounted NTFS
    volume. `NtFsControlFile` lives in Wine's Unix-side `ntdll.so`, which cannot
    be swapped in per prefix like the DLL patches so far; it needs a custom
    Wine build. Inventing values that satisfy the check is out of scope for
    this project.
- Earlier note corrected: the `c00000cb` results for `\??\G:` are not a
  permission problem; every drive letter shows them, it is how Wine routes
  volume opens.
- What the licence volume really says (`tools/ntfs_probe.py`, read-only, on the
  raw device): cluster size 4096; the nine key files are 2.5-5.4 kB each, stored
  non-resident in single runs at fixed cluster numbers; none of them, nor the
  `AX NF ZZ` folder, has an NTFS object ID. The trace shows the licence manager
  calling `FSCTL_GET_RETRIEVAL_POINTERS` on each key file, so the on-disk
  location of the files is what it looks at. Wine 11.20 answers that call with
  a fixed dummy extent at cluster 0.
- Two patches so Wine reports what is really there (need a full Wine build,
  `scripts/build-wine.sh`, because they are in Unix-side code):
  - `0007-mountmgr-ntfs-volume-serial.patch`: recognise an NTFS boot sector and
    take the volume serial number from it (needs read access to the device).
  - `0008-ntdll-retrieval-pointers-from-fiemap.patch`: answer
    `FSCTL_GET_RETRIEVAL_POINTERS` from the kernel's extent map (FIEMAP).
  Neither is built or tested yet.
- Licence manager GUI: `almapp64x.exe` starts `almgui64x.exe` with a restricted
  token (`NtFilterToken`, `TokenIntegrityLevel`, both unsupported in Wine) and
  restarts it about 90 times in a minute; no window appears, and one instance
  dies calling a null pointer. `winedbg` cannot start or attach to these
  programs; that is left alone.
- Complete custom Wine 11.20 built with patches 0001-0008
  (`scripts/build-wine.sh`, run from the build tree).
  - Switching the existing prefix to it with `wineboot -u` broke it: .NET
    programs showed "This application could not be started". Restored the
    post-install snapshot instead and disabled prefix updates
    (`.update-timestamp` = `disable`); the versions are identical, so no update
    is needed. The per-DLL overrides are gone except `wminet_utils=builtin`.
  - All earlier tests pass on the custom build: WMI from STA, named-pipe
    `File.Exists`, ECDH through `ncrypt`, CryptoAPI DH with `CALG_CYLINK_MEK`,
    Portal's 108 locale IDs.
  - New test `tests/retrieval-pointers`: for a key file on the read-only
    licence volume, Wine now reports one extent at the same cluster number
    that `tools/ntfs_probe.py` reads from the NTFS file record, and (once the
    user has read access to the block device) the same volume serial number as
    the NTFS boot sector.
  - The licence manager service starts under the custom build.
- With real serial number and file locations, Portal still reports no valid
  licence key. Per key file the licence manager reads the file, asks for its
  retrieval pointers, then `FileAllInformation`, the handle's object name, and
  `IOCTL_STORAGE_QUERY_PROPERTY` on the volume. Comparing Wine's answers with
  the NTFS file record (`tests/retrieval-pointers/fileinfo.c` against
  `tools/ntfs_probe.py`) showed three more differences in what Wine says about
  the file itself:

  | | Wine 11.20 | NTFS file record |
  |---|---|---|
  | file index | inode number only | record number plus sequence number in the top 16 bits |
  | attributes | `ARCHIVE` | `ARCHIVE`, `HIDDEN`, `SYSTEM` |
  | creation time | same as modification time | its own, earlier value |

  Patch 0008 (renamed `0008-ntdll-report-ntfs-file-location-and-metadata.patch`)
  now also reads the file record from the volume's block device and reports
  those three values. Verified for a key file; a file on ext4 is unchanged.
- Still different from Windows, and not about the volume's contents: the
  handle's object name (`\??\G:\...` instead of `\Device\HarddiskVolumeN\...`),
  the storage descriptor (bus type SCSI, no vendor or product strings) and the
  drive geometry (a fixed made-up geometry).
- Licence manager window: `almgui64x.exe` wants to run without administrator
  rights. It asks for a filtered token (`NtFilterToken` with
  `DISABLE_MAX_PRIVILEGE`), sets its integrity level to medium and restarts
  itself with it; Wine returned an equally elevated token and always reported
  the high integrity level, so it restarted itself forever.
  `patches/wine/0009-ntdll-limited-tokens-and-integrity-level.patch` hands out
  the limited token linked to an elevated one and reports medium integrity for
  non-elevated tokens. Result: the Automation License Manager window opens and
  lists the drives, including the licence volume `G:`. With `G:` selected the
  key list is empty. The launcher `almapp64x.exe` still logs one null-pointer
  fault and two unregistered COM classes. Start it with `scripts/start-alm.sh`.
- The licence manager's right-hand pane was blank. It is an embedded browser
  control ("HtmlView": WebView2 first, hidden; then the Internet Explorer
  control) showing a `res://` page from `almgui64x.exe`. Navigation failed with
  `MK_E_SYNTAX` because `mshtml.dll` was never registered in this prefix:
  the prefix was created with `mshtml` disabled (winetricks does that), so the
  `res:` protocol handler and the rest of Wine's HTML component were missing.
  `regsvr32 mshtml.dll` (64- and 32-bit) fixes it; Wine Gecko from the system
  package is picked up. The pane now renders ("License keys - <drive>").
  `create-prefix.sh` registers `mshtml` from now on. This may also explain the
  unreadable Portal crash-report window.
- User observation: the licence manager does report that upgrade licences were
  found on the licence volume.
- Licence manager key list: the page embeds an ActiveX control
  (`<object id="FileList" classid=...>`, provided by `almaxc64x.dll`). Wine's
  mshtml creates and embeds it, but with zero height: the page sizes it with
  `height: expression(document.body.clientHeight - 54)`, an Internet
  Explorer-only CSS feature that Gecko ignores.
  - `patches/wine/0010-mshtml-user-chrome-directory.patch`: Wine's Gecko asked
    for its user chrome directory ("UChrm") and got an error, so it never
    loaded `userContent.css`. It now gets `<profile>\chrome`.
  - `config/userContent.css` gives the control `height: calc(100% - 54px)`.
  - Result: the key list is visible. With the licence volume selected it shows
    seven keys with product, version, key name and licence number, matching
    the "7 License key(s)" in the status bar.
