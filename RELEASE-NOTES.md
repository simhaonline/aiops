# Release Notes - 1.0.1

## Final unified release

All maintained executable manager scripts now use manager version `1.0.1`.

### Installer

- Rebuilt `install.sh` as the complete 17-manager bootstrap.
- Exact supported bootstrap:
  `curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh | bash`
- Downloads and verifies `SHA256SUMS.txt`.
- Verifies every manager checksum, Bash syntax, help entry point and release version before installation.
- Backs up existing canonical manager scripts.
- Installs managers to canonical `/usr/local/bin` or `/usr/local/sbin` paths.
- Does not mutate managed runtimes.
- Saves installer logs under `/var/log/simha-aiops/`.

### Canonical installer

- Rebuilt `install-canonical-managers.sh`.
- Adds non-destructive `--check`.
- Uses array-safe manager membership checks.
- Supports all/selected manager installs.
- Copies legacy snapshots as read-only support data.
- Removes stale duplicate manager commands from the opposite local PATH directory after backing them up.

### Suite

- `manager-suite` standardized to version `1.0.1`.
- Added `install-order`.
- Added `dependencies`.
- Retains non-strict `verify` and strict `verify-all`.

### Legacy

- `legacy/` contains support snapshots from the pre-1.0.1 internal manager lineage.
- Legacy files are non-executable and never automatically run.

### Documentation

- Rebuilt README and dependency/installation documentation.
- Rebuilt all 19 DOCX reference documents for release 1.0.1.
- Removed duplicate/obsolete document generations from the canonical package.

### Existing fixes retained

- Docker fresh-install optional-backup return-code bug.
- Miniconda conda-forge default / Anaconda ToS handling / interactive Bash activation.
- Hermes uv/XDG ownership and root-side build prerequisite fixes.
- Harness direct-Nginx topology with legacy Plesk tunnel command surface removed.
- Nginx Harness/Hermes integration, HSTS, TLS 1.2/1.3, API Authorization forwarding mode.

## Final bootstrap hardening

- The exact `curl .../main/install.sh | bash` path now resolves `main` to one immutable Git commit before downloading `SHA256SUMS.txt` and manager payloads. This removes the multi-file race that could produce false checksum mismatches while `main` was changing.
- Legacy support snapshots are now opt-in (`AIOPS_INSTALL_LEGACY=1`) and cannot block installation of the 17 maintained managers.
- The checked-out canonical installer follows the same legacy policy.
- `freebuff-manager` no longer performs a hidden first-run native-runtime download as part of `verify`; use `freebuff-manager bootstrap` for the visible upstream download/runtime step.
- Release QA validates legacy explicitly but treats the GitHub Actions workflow as CI metadata rather than a runtime blocker.
- Added `qa/finalize-release.sh` so `MANIFEST.json` and `SHA256SUMS.txt` are regenerated in the correct order after every repository change.

## Canonical documentation cleanup

- Added `qa/cleanup-docs.sh` with the explicit 19-file canonical DOCX allowlist.
- `qa/finalize-release.sh` now removes stale historical DOCX generations before generating `MANIFEST.json` and `SHA256SUMS.txt`.
- Missing canonical documents still fail closed; only non-canonical `docs/*.docx` files are removed.

## Unix account creation reliability

- Fixed the default `system-manager` administrator creation path when the configured username is `sysadmin` and the manager-owned `sysadmin` group already exists. The account now reuses the existing group with `--gid` instead of incorrectly combining a pre-existing group with `useradd --user-group`.
- Applied the same partial-install/group-collision resilience to Docker rootless, Ollama, Harness, Hermes and LiteLLM service-account creation.
- Added an executable regression for the exact `sysadmin` failure and a cross-manager account/group collision release gate.

## Legacy support hardening

- Applied the Unix account/group collision fix to the six affected legacy support scripts: system-manager, docker-manager, ollama-manager, harness-manager, hermes-manager and litellm-manager.
- Extended release QA so maintained and legacy copies must both handle pre-existing same-name groups safely.
- Legacy files remain mode 0644 and are never installed on PATH automatically.

## System-manager pipefail and Fail2Ban correction

- Fixed `current_ssh_port`: the previous `sshd -T | awk ... exit` pipeline could make `sshd` receive SIGPIPE (exit 141) under `set -o pipefail`.
- Removed additional early-consumer `head`/`grep -q` patterns from system-manager state/firewall verification paths where they could create the same false-failure class.
- Added a managed `/etc/fail2ban/fail2ban.local` override with `[DEFAULT] allowipv6 = auto`; Fail2Ban upstream documents this as the proper local override for the startup warning.
- Applied the same system-manager fixes to the legacy support copy.
- Added executable regressions for a high-volume mocked `sshd -T` stream and the Fail2Ban global override.

## Harness Ollama model discovery

- Fixed the post-Web-preflight crash when Ollama's OpenAI-compatible `/v1/models` response contains `"data": null`.
- Harness model discovery now uses Ollama's native `/api/tags` inventory first and the OpenAI-compatible endpoint only as a fallback.
- Missing, `null`, non-list and mixed-type model collections are handled as empty/filtered discovery results instead of raising Python `TypeError`.
- Hardened npm package-version JSON parsing against `null` and empty/non-string arrays.
- Applied the same parser fixes to the legacy Harness support snapshot.
- Added regression coverage for `"data": null`, `"models": null`, malformed JSON, duplicate IDs, mixed item types, native-first discovery, and OpenAI fallback.
