# Repository Audit — Final 1.0.1

This audit records the release-normalization work performed before the final
1.0.1 package.

## Canonical source layout

- `scripts/`: exactly 20 maintained manager commands.
- `legacy/`: exactly 17 non-executable support snapshots plus `README.md`.
- `docs/`: exactly 19 current DOCX references.
- `qa/`: release validation and the two regression tests.
- root: bootstrap, canonical installer, sync helper, manifest, checksums and
  operator documentation.

## Corrected release blockers

- The one-line bootstrap now downloads and verifies all 20 maintained managers.
- Canonical manager destinations are `/usr/local/bin`, except
  `wireguard-manager` at `/usr/local/sbin`.
- Old duplicate-path manager scripts are backed up before cleanup.
- Backups preserve original `/usr/local/bin` versus `/usr/local/sbin` paths.
- The canonical installer has an array-safe manager membership check.
- The canonical `--check` gate validates maintained and legacy script sources.
- Legacy support scripts are syntax-checked and never placed on executable PATH.
- The Docker empty-backup fresh-install return-code regression remains covered.
- Harness requires both `nvm-manager` and `ollama-manager`; dependency docs/order
  are aligned with the implementation.
- Nginx keeps TLS 1.2/1.3, one-year HSTS, protected-app Authorization stripping
  and API Authorization forwarding modes.
- Miniconda keeps the conda-forge default, explicit Anaconda ToS opt-in and
  managed interactive Bash activation.
- DOCX references were rebuilt and checked for build-machine path leakage.

## Version policy

Every maintained manager command, installer, repository sync helper and QA
script belongs to release `1.0.1`. Legacy snapshots retain their historical
internal manager version for comparison but carry
`AIOPS_LEGACY_RELEASE="1.0.1"` and are non-executable support material.

## Runtime policy

The bootstrap installs manager scripts only. Runtime package/service changes
remain explicit through each manager's `install`, `repair`, `update`, `start`
and related commands.
