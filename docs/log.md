# Experiment log

## 2026-11-10

- Host: Arch-based (Omarchy), kernel 7.2, Wine 11.20, winetricks 20260125.
- Storage: 200 GB ext4 image file on an exFAT drive, mounted with `udisksctl`
  (exFAT cannot hold a Wine prefix: no symlinks, no Unix permissions).
- Inspected an installed TIA Portal V21 read-only; results in `inventory.md`.
- Started creating the prefix with .NET Framework 4.8 (`scripts/create-prefix.sh`).
