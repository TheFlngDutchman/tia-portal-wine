# What TIA Portal V21 is made of

Taken from an existing, licensed Windows 11 installation, mounted read-only
(`scripts/inventory.sh` and an offline read of the Windows service list).
Date: 2026-11-10.

## Application

| Item | Value |
|------|-------|
| Install directory | `Program Files\Siemens\Automation\Portal V21`, 16 GB |
| Executables / DLLs | 70 / 4789 |
| Main executable | `Bin\Siemens.Automation.Portal.exe`, 64-bit .NET assembly |
| Target runtime | .NET Framework 4.8 (`supportedRuntime v4.0`, server GC enabled) |
| UI technology | .NET (WinForms/WPF) plus an embedded Qt WebEngine (`QtWebEngineProcess.exe`) |
| Shared Siemens components | about 1 GB in `Common Files\Siemens`, 13 GB in `ProgramData\Siemens` |

## Windows services installed alongside it

| Service | Program | Purpose (as far as known) |
|---------|---------|---------------------------|
| `almservice` | `almsrv64x.exe` | Automation License Manager |
| `s7oiehsx64` | `s7oiehsx64.exe` | SIMATIC IEPG helper (online access over Ethernet) |
| `SIMATIC PnDiscovery Service` | `s7oPNDiscoveryx64.exe` | PROFINET device discovery |
| `S7TraceServiceX`, `TraceConceptX` | | tracing |
| `SiemensTiaAdmin`, `SiemensTiaAdminV3`, `SiemensTiaAdminV3.System` | `node.exe` | TIA Administrator (Node.js web services) |
| `Siemens TIA Help Viewer Service` | | help system |
| `Siemens Add-In Rollout Service` | | add-ins |
| `umscsvc` | `IPCSecCom.exe` | user management |
| `Siemens Telemetry Connector Service`, `Siemens Diagnostics Data Collector Service` | | telemetry and diagnostics |

## Kernel drivers

`sntie`, `snpnio`, `s7PnDiscoveryDriver` (start automatically), `plcsimlwf`,
`plcsimvmini60`, `vsnl2ada`, `dpmconv`, `cortkbdrtmwdf`, and the `s7o*` family
(`s7odpx2x64`, `s7oppilx64`, `s7oppinx64`, `s7oserix64`, `s7osmcax64`,
`s7osobux64`, `s7otmcd64x`, `s7otranx64`, `s7otsadx64`, `s7ousbu64x`).

Several of these are network filter and protocol drivers (NDIS). They provide
PROFINET discovery, the "PG/PC interface", and the PLCSIM virtual adapter.

## Expected difficulty under Wine

| Area | Outlook | Why |
|------|---------|-----|
| .NET Framework 4.8 | workable | installs through winetricks; WinForms is solid, WPF is less reliable |
| Qt WebEngine parts | uncertain | Chromium-based processes often need sandbox flags under Wine |
| Installer | uncertain | a long chain of MSI packages, services and driver installs; driver steps will fail and must be tolerated |
| Windows services | uncertain | Wine can run ordinary services; each one has to be tested |
| Licence manager | unknown | untested under Wine; it will not be bypassed in this project |
| Kernel drivers | blocked | Wine cannot load NDIS drivers. Online access, device discovery and PLCSIM depend on them |

The last row is why goal 6 in the README may not be reachable with Wine alone.
Plain TCP/IP online access to S7-1200/1500 might work without the NDIS drivers
if the user-mode part of the stack accepts a normal socket path; this has to be
tested and is not known.
