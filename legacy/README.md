# Legacy support snapshots

This directory contains **non-executable support snapshots** from the manager lineage immediately before the unified `1.0.1` release.

Rules:

- `legacy/` is not part of the executable PATH.
- The one-line installer does not execute these files.
- Canonical maintained managers live in `scripts/`.
- Use legacy files only for rollback comparison, incident analysis, or migration support.
- Do not copy a legacy file over a canonical manager without reviewing its older security/runtime assumptions.

The canonical installer can copy this directory to `/usr/local/share/simha-aiops/legacy/` as read-only support material.
