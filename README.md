# tia-portal-wine

An experiment: can Siemens TIA Portal V21 run on Linux under [Wine](https://www.winehq.org/)?

**Status: experimental. TIA Portal V21 installs (with failures) and its main
window starts; nothing beyond that is verified, and the licence manager does not
run.** There is no published
working setup for any recent TIA Portal version under Wine, and Siemens supports
Windows only. This repository records what was tried, what broke, and why, so that
the work is reproducible and others can pick it up.

Not affiliated with or endorsed by Siemens. TIA Portal, SIMATIC and STEP 7 are
trademarks of Siemens AG.

## What this repository contains

- `scripts/` — setup and test scripts (storage, Wine prefix, read-only inspection of
  an existing Windows install, logged test runs)
- `docs/inventory.md` — what an installed TIA Portal V21 consists of and which parts
  are expected to be hard under Wine
- `docs/log.md` — dated experiment log

It contains **no Siemens software**: no binaries, installers, registry exports,
decompiled code or licence data. You need your own licensed copy of TIA Portal.

## Ground rules

- The licence mechanism (Automation License Manager) is not bypassed, patched or
  emulated. The goal is to run a properly licensed installation.
- Fixes go into Wine configuration or Wine itself, not into Siemens binaries.
- Analysis of the software (for example with [REA](https://github.com/morluto/rea))
  is limited to what is needed to make it interoperate with Wine. Findings are
  described in prose; no Siemens code is published.

## Goals, in order

| # | Goal | State |
|---|------|-------|
| 1 | Wine prefix with .NET Framework 4.8 | done |
| 2 | TIA Portal installer completes | mostly: 54 of 58 packages install; drivers, licence manager and ProSave fail |
| 3 | Portal starts and shows its main window | reached with the Wine patches in `patches/wine` |
| 4 | Open, edit and compile a project offline | partly: a new project can be created; opening an existing one reaches the product check. Editing and compiling not tested |
| 5 | Licence recognised by Automation License Manager | partly: the service and its window run and list the keys on a mounted licence volume; whether Portal accepts them is open |
| 6 | Go online / download to a PLC over Ethernet | not started, expected to be the hardest |

Goal 6 depends on Siemens kernel-mode network drivers, which Wine cannot load.
It may turn out to be impossible without a different approach. See
`docs/inventory.md`.

## Quick start

Requirements: Arch Linux (or similar) with `wine`, `winetricks`, `cabextract`,
`hivex`, `samba` (for `ntlm_auth`), `mingw-w64-gcc`, Wine's build dependencies,
and about 100 GB of space on a Linux filesystem.

```bash
. scripts/env.sh               # paths; override via environment variables
scripts/mount-storage.sh       # optional: ext4 image on an exFAT/NTFS drive
scripts/create-prefix.sh       # 64-bit prefix + .NET Framework 4.8 (system Wine)
scripts/build-wine.sh          # complete Wine with patches/wine applied
scripts/start-portal.sh        # after installing TIA Portal into the prefix
```

`scripts/build-wine.sh` builds the same Wine version as the installed one and
runs it from its build tree; `env.sh` puts it first in `PATH`. Two things to
know when switching an existing prefix to it:

- Write `disable` into `<prefix>/.update-timestamp`. Otherwise the first start
  runs a prefix update, which left .NET applications unable to start here.
- Copy `config/userContent.css` to
  `<prefix>/drive_c/users/<user>/AppData/Roaming/wine_gecko/chrome/` (needs
  patch 0010). It replaces Internet Explorer-only CSS in embedded Siemens pages.
- Set the DLL override `wminet_utils=builtin`, so that Wine's `wminet_utils`
  is used instead of the one .NET 4.8 installs.

`scripts/build-wine-patches.sh` is the earlier approach (single patched DLLs
installed as native overrides on top of the system Wine). It cannot carry
patches 0007 and 0008.

## Licence

The scripts and documentation in this repository are MIT licensed. See `LICENSE`.
