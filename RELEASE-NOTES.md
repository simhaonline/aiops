# Release Notes - 1.0.0

## Final unified release

All maintained executable manager scripts now use manager version `1.0.0`.

### Installer

- Rebuilt `install.sh` as the complete 23-command suite bootstrap.
- Added `aiops`, a safe phase-aware CLI dispatcher for every runtime manager.
- Moved WireGuard client exports to `/etc/wireguard/client`, including automatic migration from the legacy root-home location.
- Added an enforced Ollama Cloud-only model catalog and post-install model selector.
- Added root-only NVIDIA NIM/OpenRouter credentials and fail-closed free-model discovery for LiteLLM.
- Added daily/weekly cron orchestration for NVIDIA, OpenRouter, and Ollama Cloud model refreshes.
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
- Removes stale duplicate manager commands from the opposite local PATH directory after backing them up.

### Suite

- `manager-suite` standardized to version `1.0.0`.
- Added `install-order`.
- Added `dependencies`.
- Retains non-strict `verify` and strict `verify-all`.

### Documentation

- Maintains README, administrator, user, project-isolation, dependency,
  installation, security and release documentation as source Markdown.
- Removed generated DOCX copies and historical release artifacts.
- Added `ARCHITECTURE-REPORT.md` covering project scope, module boundaries,
  request lifecycles, coupling, state models, ADRs, conventions, and Mermaid
  diagrams.
- Added native SIMHA Studio product documentation and capability boundaries.

### Native SIMHA Studio

- Added a first-party responsive Studio shell without embedding or forking UI
  code from LibreChat, LobeHub, AnythingLLM, or Langflow.
- Added native surfaces for text, codebases, PDF/documents, image, video, voice,
  translation, knowledge, workflows, projects, registry, and operations.
- Added the NestJS workspace capability contract for modality actions, registry
  lifecycle states, LiteLLM routing policy, and safety boundaries.
- Added quarantine-first governance for discovered skills, agents, MCP servers,
  and plugins; automatic installation is disabled.
- Enabled same-origin camera/microphone and blob media policies for future media
  workflows while retaining the loopback/private deployment boundary.
- Documented the current boundary: UI/capability foundation first, followed by
  conversation persistence, streaming, ingestion, media workers, translation,
  registry collection, and workflow execution layers.

### Existing fixes retained

- Docker fresh-install optional-backup return-code bug.
- Miniconda conda-forge default / Anaconda ToS handling / interactive Bash activation.
- Hermes uv/XDG ownership and root-side build prerequisite fixes.
- Harness direct-Nginx topology with legacy Plesk tunnel command surface removed.
- Nginx Harness/Hermes integration, HSTS, TLS 1.2/1.3, API Authorization forwarding mode.

## Final bootstrap hardening

- The exact `curl .../main/install.sh | bash` path now resolves `main` to one immutable Git commit before downloading `SHA256SUMS.txt` and manager payloads. This removes the multi-file race that could produce false checksum mismatches while `main` was changing.

## Isolated project development

- Added `project-manager` for one-container-per-project development environments.
- Project HOME, Codex home, skills, plugins, MCP configuration, dependencies,
  network and agent state are isolated from the host and other projects.
- Added full project backup with SHA-256 sidecars and traversal-safe restore into
  an absent or empty destination.
- Generated containers omit the host Docker socket, run unprivileged, drop Linux
  capabilities and enable `no-new-privileges`.
- Added per-project code-server, Goose, OpenCodex and MuleRouter feature support.
- MuleRouter keys and generated code-server credentials stay in project-only
  secret files rather than images or versioned project environment files.
- Added automatic code-server port allocation from `18080-18999` and a managed
  project edge lifecycle with loopback health checks, Nginx Basic Auth, TLS,
  WebSocket forwarding, association tracking, and orphan-proxy prevention.
- Added missing HTTPS edge helpers for the Codex App Server and OpenCode Web.
  CLI-only tools remain intentionally unproxied, and Ollama remains private.
- Added project-local AGENTS/skill/plugin/MCP governance with locked asset
  checksums, symlink rejection, disabled-by-default MCP definitions, inline
  secret rejection and a unified AI configuration audit.
- Added `collection-manager` using pinned Scrapling workers, authorized HTTPS
  source policy, domain allowlists, AI-targeted extraction, resource limits,
  checksum-protected outputs, a read-only loopback dashboard, managed Nginx/TLS
  publication, and independent backup/restore.
- Added an optional professional AiOps dashboard: responsive Next.js light/dark
  UI, validated NestJS API, dependency-free Python host telemetry, and a Go
  Unix-socket broker restricted to five allowlisted operations. Project
  start/stop is excluded from the privileged broker because project Compose
  files are user-editable. Web containers are loopback-only, capability-free,
  read-only, and never mount Docker socket.

## Forgejo infrastructure

- Added a rootless Forgejo 16.0.1 + PostgreSQL stack with loopback defaults,
  disabled public registration and a private database network.
- Added consistent stop/snapshot/restart backup and destructive-confirmed
  restore for Forgejo application and database volumes.
- Added a separate Forgejo Runner manager using a dedicated Unix identity and
  rootless Podman socket.
- Added checksum-backed runner registration backup and confirmed restore.
- Runner policy rejects host labels, privileged execution, rootful Docker
  sockets and job images that are not pinned by SHA-256 digest.

## Operations documentation

- Added an administrator operations guide covering trust zones, deployment,
  lifecycle, security, monitoring, backup, restore, incidents and change control.
- Added a user operations guide for daily isolated project, IDE, agent, provider,
  Forgejo, backup and recovery workflows.
- `freebuff-manager` no longer performs a hidden first-run native-runtime download as part of `verify`; use `freebuff-manager bootstrap` for the visible upstream download/runtime step.
- Added `qa/finalize-release.sh` so `MANIFEST.json` and `SHA256SUMS.txt` are regenerated in the correct order after every repository change.

## Repository cleanup

- Removed legacy manager snapshots, duplicate DOCX references, obsolete upload
  helpers, static QA reports, and historical repository-audit artifacts.
- Release metadata is generated only from maintained operational files.

## Unix account creation reliability

- Fixed the default `system-manager` administrator creation path when the configured username is `sysadmin` and the manager-owned `sysadmin` group already exists. The account now reuses the existing group with `--gid` instead of incorrectly combining a pre-existing group with `useradd --user-group`.
- Applied the same partial-install/group-collision resilience to Docker rootless, Ollama, Harness, Hermes and LiteLLM service-account creation.
- Added an executable regression for the exact `sysadmin` failure and a cross-manager account/group collision release gate.

## System-manager pipefail and Fail2Ban correction

- Fixed `current_ssh_port`: the previous `sshd -T | awk ... exit` pipeline could make `sshd` receive SIGPIPE (exit 141) under `set -o pipefail`.
- Removed additional early-consumer `head`/`grep -q` patterns from system-manager state/firewall verification paths where they could create the same false-failure class.
- Added a managed `/etc/fail2ban/fail2ban.local` override with `[DEFAULT] allowipv6 = auto`; Fail2Ban upstream documents this as the proper local override for the startup warning.
- Added executable regressions for a high-volume mocked `sshd -T` stream and the Fail2Ban global override.

## Harness Ollama model discovery

- Fixed the post-Web-preflight crash when Ollama's OpenAI-compatible `/v1/models` response contains `"data": null`.
- Harness model discovery now uses Ollama's native `/api/tags` inventory first and the OpenAI-compatible endpoint only as a fallback.
- Missing, `null`, non-list and mixed-type model collections are handled as empty/filtered discovery results instead of raising Python `TypeError`.
- Hardened npm package-version JSON parsing against `null` and empty/non-string arrays.
- Added regression coverage for `"data": null`, `"models": null`, malformed JSON, duplicate IDs, mixed item types, native-first discovery, and OpenAI fallback.
