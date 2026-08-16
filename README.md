<p align="center">
  <img src="https://img.shields.io/badge/SIMHA-AiOps-102421?style=for-the-badge&logo=linux&logoColor=white" alt="SIMHA AiOps" />
</p>

<h1 align="center">SIMHA AiOps Manager Suite</h1>

<p align="center">
  <a href="https://github.com/simhaonline/aiops/releases"><img src="https://img.shields.io/badge/release-v1.0.0-e65b35?style=flat-square" alt="Release v1.0.0" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-1d755f?style=flat-square" alt="MIT License" /></a>
  <a href="https://github.com/simhaonline/aiops/actions"><img src="https://img.shields.io/badge/validation-passing-1d755f?style=flat-square&logo=githubactions&logoColor=white" alt="Validation passing" /></a>
  <a href="https://ubuntu.com/download/server"><img src="https://img.shields.io/badge/platform-Ubuntu%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04" /></a>
</p>

<p align="center">
  <a href="dashboard/PRODUCT.md"><img src="https://img.shields.io/badge/UI-SIMHA%20Studio-102421?style=flat-square&logo=react&logoColor=white" alt="SIMHA Studio" /></a>
  <a href="SECURITY.md"><img src="https://img.shields.io/badge/security-loopback%20%2B%20broker-1d755f?style=flat-square&logo=letsencrypt&logoColor=white" alt="Loopback and broker security" /></a>
  <a href="THIRD-PARTY-NOTICES.md"><img src="https://img.shields.io/badge/credits-third--party%20notices-61706d?style=flat-square&logo=opensourceinitiative&logoColor=white" alt="Third-party notices" /></a>
</p>

<p align="center"><em>Secure lifecycle management for AI runtimes, isolated projects, providers, and operations.</em></p>

**Release:** `1.0.0`
**Target OS:** Ubuntu Server 24.04 LTS  
**Repository:** `simhaonline/aiops`

### Technology and integration badges

<p>
  <a href="dashboard/apps/web/package.json"><img src="https://img.shields.io/badge/Next.js-16-000000?style=flat-square&logo=nextdotjs&logoColor=white" alt="Next.js 16" /></a>
  <a href="dashboard/apps/api/package.json"><img src="https://img.shields.io/badge/NestJS-11-E0234E?style=flat-square&logo=nestjs&logoColor=white" alt="NestJS 11" /></a>
  <a href="dashboard/broker/go.mod"><img src="https://img.shields.io/badge/Go-broker-00ADD8?style=flat-square&logo=go&logoColor=white" alt="Go broker" /></a>
  <a href="dashboard/telemetry/collector.py"><img src="https://img.shields.io/badge/Python-telemetry-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python telemetry" /></a>
  <a href="scripts/litellm-manager"><img src="https://img.shields.io/badge/LiteLLM-routing-5B3DF5?style=flat-square" alt="LiteLLM routing" /></a>
  <a href="scripts/ollama-manager"><img src="https://img.shields.io/badge/Ollama-Cloud%20models-000000?style=flat-square" alt="Ollama Cloud models" /></a>
  <a href="scripts/wireguard-manager"><img src="https://img.shields.io/badge/WireGuard-VPN-88171A?style=flat-square" alt="WireGuard VPN" /></a>
  <a href="scripts/nginx-manager"><img src="https://img.shields.io/badge/Nginx-TLS%20edge-009639?style=flat-square&logo=nginx&logoColor=white" alt="Nginx TLS edge" /></a>
  <a href="scripts/collection-manager"><img src="https://img.shields.io/badge/Scrapling-restricted%20collector-61706d?style=flat-square" alt="Scrapling restricted collector" /></a>
</p>

Badges identify the technologies and integrations used by the repository; they
are not endorsements. Ownership, trademarks, licenses, and upstream links are
listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

Simha AiOps is a production-oriented collection of lifecycle managers for operating an AI development/inference server without mixing every runtime into one monolithic installer.

Operational documentation:

- [Administrator Operations Guide](ADMIN-GUIDE.md)
- [User Operations Guide](USER-GUIDE.md)
- [Project Isolation Guide](PROJECT-ISOLATION.md)
- [Architecture, Lifecycle, and Context Report](ARCHITECTURE-REPORT.md)
- [Third-Party Notices and Attributions](THIRD-PARTY-NOTICES.md)

## Copyright, trademarks, and third-party credits

SIMHA AiOps source code and original documentation are Copyright (c) 2026
Simha.Online and are provided under the MIT License in `LICENSE`.

This repository integrates with, builds around, or can invoke external projects
and services including Next.js, React, NestJS, Fastify, TypeScript, Node.js, Go,
Python, Docker, Nginx, Certbot, WireGuard, Forgejo, LiteLLM, Ollama, NVIDIA NIM,
OpenRouter, Scrapling, and Goose. Their names and links are listed in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Each remains governed by its
own license and terms; this repository does not transfer ownership or relicense
third-party code.

All trademarks, service marks, trade names, product names, logos, and brands
mentioned in this repository are the property of their respective owners. Their
use is for identification, interoperability, documentation, or compatibility
only and does not imply endorsement, sponsorship, affiliation, or ownership.

LibreChat, LobeHub, AnythingLLM, and Langflow informed product research only;
their application code is not bundled or forked in SIMHA Studio. Scrapling is
used as a separately pinned collection worker, as documented in the notices.

The maintained manager scripts are in `scripts/`; no historical manager copies
are shipped in the production repository.

## Quick install

The supported one-line bootstrap is:

```bash
curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh | bash
```

This command:

1. requires Ubuntu 24.04 LTS for install mode;
2. resolves `main` (or the requested tag) to one immutable Git commit before downloading the release payload;
3. downloads `SHA256SUMS.txt` from that exact commit;
4. downloads all **23** maintained suite commands from the same commit;
5. verifies every downloaded manager against the checksum manifest;
6. runs Bash syntax, `help`, and version checks;
7. backs up existing canonical manager commands;
8. installs 16 managers to `/usr/local/bin`;
9. installs `wireguard-manager` to `/usr/local/sbin`;
10. writes an installer log under `/var/log/simha-aiops/`.

**The bootstrap installs manager scripts only. It does not automatically install, repair, start, restart, update, or purge the managed runtimes.**

That separation is intentional: installing manager commands is low risk; runtime installation can modify packages, services, firewall policy, credentials, or application state and therefore remains explicit.

### Reproducible production install

`main` is mutable. For repeatable production deployment, pin a release tag or commit:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/simhaonline/aiops/v1.0.0/install.sh \
  | AIOPS_REF=v1.0.0 AIOPS_REQUIRE_PIN=1 bash
```

You can also perform a download/verification-only bootstrap test:

```bash
curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh \
  | AIOPS_DRY_RUN=1 bash
```

## Maintained managers

| Manager | Version | Purpose | Primary dependency |
|---|---:|---|---|
| `system-manager` | 1.0.0 | Ubuntu base security/packages/SSH/UFW/limits/time | Ubuntu 24.04 |
| `docker-manager` | 1.0.0 | Host Docker + managed rootless Docker | system baseline recommended |
| `forgejo-manager` | 1.0.0 | Rootless Forgejo + PostgreSQL, backup and restore | **requires rootless Docker** |
| `forgejo-runner-manager` | 1.0.0 | Dedicated rootless Podman Actions runner | separate VM recommended |
| `gvm-manager` | 1.0.0 | Root-scoped GVM/Go | system baseline recommended |
| `miniconda-manager` | 1.0.0 | System-wide Miniconda | system baseline recommended |
| `nvm-manager` | 1.0.0 | Root NVM/Node/PM2 | system baseline recommended |
| `ollama-manager` | 1.0.0 | Ollama Cloud/local loopback API policy | system baseline recommended |
| `nginx-manager` | 1.0.0 | Nginx/Certbot reverse proxy and TLS | system baseline recommended |
| `wireguard-manager` | 1.0.0 | WireGuard VPN | system baseline recommended |
| `harness-manager` | 1.0.0 | DeepSeek Harness CLI/Web service | **requires `nvm-manager` and `ollama-manager`** |
| `hermes-manager` | 1.0.0 | Hermes CLI + loopback Dashboard | system build packages |
| `codex-manager` | 1.0.0 | OpenAI Codex CLI/App Server lifecycle | system base utilities |
| `claude-manager` | 1.0.0 | Claude Code lifecycle | system base utilities |
| `opencode-manager` | 1.0.0 | OpenCode CLI/server lifecycle | **requires `nvm-manager`** |
| `freebuff-manager` | 1.0.0 | Freebuff CLI lifecycle | **requires `nvm-manager`** |
| `litellm-manager` | 1.0.0 | LiteLLM Proxy lifecycle | Python/venv/build baseline |
| `llmrouter-manager` | 1.0.0 | LMRouter CLI/API lifecycle | **requires `nvm-manager`** |
| `project-manager` | 1.0.0 | Isolated per-project development, backup and restore | **requires Docker Compose** |
| `collection-manager` | 1.0.0 | Isolated Scrapling collection policy, crawl, UI and recovery | **requires `project-manager` and Docker** |
| `aiops-dashboard-manager` | 1.0.0 | Next.js/NestJS operations UI, Go broker and Python telemetry | **requires Docker and dashboard source** |
| `manager-suite` | 1.0.0 | Cross-manager inventory/status/verification | none |
| `aiops` | 1.0.0 | Unified, phase-aware command dispatcher for all runtime managers | manager scripts |

Runtime/upstream application versions are independent from the manager suite version. For example, `nvm-manager 1.0.0` can manage a newer Node release without changing the manager's own version.

## Recommended runtime installation sequence

The bootstrap above installs all manager **commands** in one operation. When installing actual runtimes, use this order:

```text
Phase 1 - Base OS
  1. system-manager

Phase 2 - Core runtimes
  2. docker-manager
  3. forgejo-manager (optional)
  4. forgejo-runner-manager (optional, separate execution plane)
  5. gvm-manager
  6. miniconda-manager
  7. nvm-manager

Phase 3 - AI runtime and edge
  8. ollama-manager
  9. nginx-manager
 10. wireguard-manager

Phase 4 - AI agents
 11. harness-manager
 12. hermes-manager
 13. codex-manager
 14. claude-manager
 15. opencode-manager
 16. freebuff-manager

Phase 5 - AI gateways/routing
 17. litellm-manager
 18. llmrouter-manager

Phase 6 - Isolated development and health gate
 19. project-manager
 20. collection-manager (optional)
 21. aiops-dashboard-manager (optional)
  22. manager-suite
 23. aiops (unified operational CLI)
```

Display the same sequence from the installed suite:

```bash
manager-suite install-order
manager-suite dependencies
aiops list
```

Run one manager through the unified CLI, or safely preview a phase-wide action:

```bash
sudo aiops run docker-manager -- status
aiops run --phase agents --dry-run -- verify
sudo aiops run --phase agents --continue-on-error -- restart
```

Mutating commands across multiple managers require `--yes`; use `--dry-run`
first. Everything after `--` is passed literally to each selected manager.

You do **not** have to install every runtime. Install only the components the server actually needs.

## Isolated project development

Host-level runtime managers are useful for server infrastructure, but they do
not isolate one development project from another. Use `project-manager` when
projects need different AGENTS.md instructions, Codex configuration, MCP
servers, skills, plugins, credentials, dependencies, or agent state:

```bash
project-manager init /srv/projects/example example
project-manager up /srv/projects/example
project-manager shell /srv/projects/example
```

Each project receives a dedicated container, home directory, `CODEX_HOME`,
Compose network, runtime definition, and source mount. Host AI configuration and
the Docker socket are not mounted. See [PROJECT-ISOLATION.md](PROJECT-ISOLATION.md)
for customization, security boundaries, backup, and restore.

Optional project features keep their state within that same boundary:

```bash
project-manager feature-enable /srv/projects/example code-server
project-manager feature-enable /srv/projects/example goose
project-manager feature-enable /srv/projects/example opencodex
project-manager feature-enable /srv/projects/example mulerouter
project-manager tool-install /srv/projects/example goose
project-manager secret-set /srv/projects/example mulerouter
```

`project-manager init` allocates a loopback UI port from `18080-18999`. Publish
an enabled code-server through the managed HTTPS edge after starting it:

```bash
sudo project-manager edge-add /srv/projects/example code-server \
  ide.example.com admin@example.com projectadmin
project-manager edges /srv/projects/example
```

The edge uses Nginx Basic Auth, TLS, WebSocket support, and a loopback-only
upstream. Remove it before disabling code-server or destroying the project:

```bash
sudo project-manager edge-remove /srv/projects/example code-server
```

Project AI assets are explicit, local and auditable:

```bash
project-manager asset-add /srv/projects/example skill review-workflow ./skill-source
project-manager asset-add /srv/projects/example plugin team-tools ./plugin-source
project-manager mcp /srv/projects/example add repository-mcp repository-mcp --stdio
project-manager mcp /srv/projects/example enable repository-mcp
project-manager asset-verify /srv/projects/example
project-manager ai-audit /srv/projects/example
```

Skills require `SKILL.md`; plugins require `.codex-plugin/plugin.json`. Installed
bytes are copied into the isolated `CODEX_HOME` and locked by checksum. MCP
definitions reject inline credentials; inject secrets through the protected
project runtime secret file.

## Isolated collection management

`collection-manager` uses a version-pinned Scrapling worker to collect only an
explicit HTTPS target under its recorded domain allowlist:

```bash
collection-manager init /srv/projects/example docs https://example.com/docs
collection-manager crawl /srv/projects/example docs
collection-manager verify /srv/projects/example
sudo collection-manager install
sudo collection-manager schedule-add /srv/projects/example docs daily
collection-manager ui-enable /srv/projects/example
project-manager up /srv/projects/example
sudo collection-manager edge-add /srv/projects/example \
  collections.example.com admin@example.com collectionadmin
```

Collected Markdown and SHA-256 sidecars remain under the project. The worker is
ephemeral, capability-free, read-only, resource-limited and uses AI-targeted
extraction. The dashboard binds only to its automatically allocated loopback
port; Nginx supplies Basic Auth and TLS. Collection backup and restore are
separate so large datasets need not be included in every project backup.

## AiOps operations dashboard

The optional dashboard is a four-process control plane with a responsive,
accessible light/dark SIMHA Studio interface:

```bash
sudo aiops-dashboard-manager install /path/to/aiops/dashboard
sudo aiops-dashboard-manager verify
sudo aiops-dashboard-manager nginx-setup ops.example.com admin@example.com aiopsadmin
```

Next.js serves the native Studio interface, NestJS provides validated APIs,
Python exports host telemetry, and a small Go broker owns the only privileged
boundary. Studio exposes text, codebase, PDF/document, image, video, voice,
translation, knowledge, workflow, project, registry, and operations surfaces.
The capability contract routes through LiteLLM using capability-aware,
verified-free-first model policy with explicit fallbacks. The web containers do
not mount the Docker socket and cannot execute arbitrary commands. Its mutation
API accepts only five explicit operations (`manager.verify`, project verification
and backup, and collection crawl/verification). It deliberately does not start
or stop user-editable project Compose files through the privileged broker.
Requests validate direct `/srv/projects` targets, time out execution, truncate
output, and write a JSON audit record.
For SaaS deployments, PostgreSQL is the system of record, pgvector stores
embeddings, and TimescaleDB stores time-series usage and telemetry. The
tenant-isolated schema and migration guidance are in
[`dashboard/database/`](dashboard/database/). Existing CLI managers remain
self-hosted and additive; tenant workloads do not receive access to the host
broker.
The current Studio release establishes the UI and capability contract; full
conversation persistence, streaming inference, media workers, and workflow
execution remain subsequent backend layers. See
[ARCHITECTURE-REPORT.md](ARCHITECTURE-REPORT.md).

### Platform management portal

The platform portal is available at `/usage` (and the management routes listed
below) with its own responsive sidebar, organization switcher, usage/balance
cards, GMT+4 context, filters, export feedback, light/dark theme, billing
links, and safe empty states:

`/home`, `/usage`, `/api-keys`, `/playground`, `/models`, `/logs`, `/batches`,
`/storage`, `/webhooks`, `/billing`, `/top-up`, `/invoices`, `/users`,
`/teams`, `/projects`, `/audit-logs`, `/security`, `/settings`, `/docs`.

The Usage view is currently mock-backed and intentionally does not claim live
billing, authentication, payment processing, or API-key persistence. Those
features connect to the tenant-aware PostgreSQL SaaS layer as they are
implemented. Marketing claims about quantum computing, compliance, or measured
performance must not be published without verified product evidence.

```bash
project-manager backup /srv/projects/example /srv/backups/example.tar.gz
project-manager restore /srv/backups/example.tar.gz /srv/projects/example-restored
```

## Forgejo and Actions

Forgejo is shared source-control infrastructure, while its Actions runner is a
separate remote-code-execution trust zone:

```bash
sudo docker-manager install
sudo forgejo-manager install
sudo forgejo-manager start
sudo forgejo-manager verify
```

Forgejo uses the dedicated rootless Docker daemon, a rootless Forgejo image,
PostgreSQL, loopback-only HTTP/SSH defaults, disabled public registration and a
private database network. Publish HTTP through the managed Nginx TLS edge.

Install the runner on a separate VM whenever untrusted contributors can change
workflows. The runner manager uses its own Unix account and rootless Podman
socket and rejects host labels, privileged jobs, rootful Docker sockets and
unpinned job images:

```bash
sudo forgejo-runner-manager install PINNED_VERSION
sudo forgejo-runner-manager configure \
  https://git.example.com/ RUNNER_UUID \
  docker.io/library/node@sha256:FULL_DIGEST
sudo forgejo-runner-manager start
```

Runner registration configuration also supports restricted backup and
confirmed restore with `forgejo-runner-manager backup` and `restore FILE --yes`.

Consistent Forgejo backup stops the stack, snapshots both named volumes, and
restarts it if it was previously running:

```bash
sudo forgejo-manager backup /srv/backups/forgejo.tar.gz
sudo forgejo-manager restore /srv/backups/forgejo.tar.gz --yes
```

## First server setup

After the one-line bootstrap:

```bash
manager-suite versions
manager-suite install-order
```

Establish the Ubuntu baseline:

```bash
sudo system-manager install
sudo system-manager verify
```

Then install individual runtimes as required, for example:

```bash
sudo nvm-manager install
sudo ollama-manager install
sudo harness-manager install
```

Finish with:

```bash
sudo manager-suite verify
```

`manager-suite verify` skips runtimes that are not installed. `manager-suite verify-all` is strict and expects every manager/runtime to exist.

## Existing server / upgrade

Re-running the one-line bootstrap updates the **manager script files** to the current release and backs up the previous canonical scripts. It does not automatically call each manager's `update` or `repair`.

After updating manager scripts:

```bash
manager-suite versions
sudo manager-suite verify
```

If a particular runtime needs its managed configuration reconciled:

```bash
sudo <manager> repair
sudo <manager> verify
```

Examples:

```bash
sudo docker-manager repair
sudo miniconda-manager repair
sudo hermes-manager repair
sudo nginx-manager repair
```

## Repository installation

For a checked-out repository, first validate it without installing:

```bash
bash ./install-canonical-managers.sh --check
```

Install every canonical manager script:

```bash
sudo bash ./install-canonical-managers.sh all
```

Or install selected manager commands:

```bash
sudo bash ./install-canonical-managers.sh system-manager docker-manager nvm-manager
```

## Logs and backups

The one-line bootstrap stores its log under:

```text
/var/log/simha-aiops/install-<UTC timestamp>.log
```

Previous canonical manager scripts are backed up under:

```text
/var/backups/simha-aiops/manager-scripts/<UTC timestamp>/
```

Individual managers maintain their own logs, state directories, and backups.
See the administrator, user, and project-isolation Markdown guides.

## Security model

Key suite rules:

- Ubuntu 24.04 LTS is the validated host OS.
- No `curl | bash` is used internally to install third-party runtimes when a safer staged method is available.
- Manager mutations use root only where required.
- Backend web/API services default to loopback.
- Nginx is the public TLS edge for services intentionally exposed.
- Harness, Hermes, Ollama, LiteLLM, LMRouter and similar backends should not be opened directly to the Internet by changing their bind addresses.
- Credentials/configuration files use restricted permissions where the manager owns them.
- Repair operations are intended to be idempotent and non-destructive.
- The suite does not silently accept third-party legal Terms of Service.

## Nginx edge policy

The Nginx manager distinguishes between edge-authenticated applications and API gateways:

- `proxy-add`, `harness-setup`, `hermes-setup`: Nginx Basic Auth can be used and the edge Authorization header is stripped before proxying.
- `proxy-add-api`: application/API Authorization is preserved for upstream Bearer/API-key authentication.
- TLS policy includes TLS 1.2/1.3.
- HSTS default:

```nginx
add_header Strict-Transport-Security "max-age=31536000" always;
```

`includeSubDomains` and `preload` are intentionally not forced globally.

## Miniconda policy

The maintained Miniconda manager:

- uses `conda-forge` as the default global channel;
- keeps strict channel priority;
- does not silently accept Anaconda Terms of Service;
- keeps `base` auto-activation disabled;
- provides managed interactive Bash integration so `conda activate ENV` works without per-user `conda init`.

## Repository layout

```text
.
├── scripts/                 # 23 maintained suite commands
├── dashboard/               # Next.js, NestJS, Go broker, Python telemetry
├── qa/                      # release validation/regression checks
├── README.md
├── ADMIN-GUIDE.md
├── USER-GUIDE.md
├── PROJECT-ISOLATION.md
├── DEPENDENCIES.md
├── INSTALLATION-ORDER.md
├── SECURITY.md
├── RELEASE-NOTES.md
├── MANIFEST.json
├── SHA256SUMS.txt
├── install.sh
└── install-canonical-managers.sh
```

## Release validation

Before publishing:

```bash
bash qa/validate-release.sh
```

The release gate checks:

- exactly 23 maintained suite commands;
- all maintained managers are version `1.0.0`;
- Bash syntax;
- manager `help` entry points;
- canonical installer `--check`;
- checksums;
- repository inventory;
- Docker fresh-install regression;
- system-manager regression;
- absence of private keys and obvious credential material.

## Important operational rule

Do not confuse:

```text
manager installed
```

with:

```text
runtime installed and verified
```

The bootstrap installs lifecycle **management commands**. Each runtime remains an explicit operator decision.

---

SIMHA AiOps Manager Suite `1.0.0`


## Freebuff first-run runtime

`freebuff-manager install` verifies the npm launcher and canonical wrapper without hiding a first-run network failure. The native Freebuff runtime is downloaded separately by the upstream launcher:

```bash
sudo freebuff-manager install
sudo freebuff-manager bootstrap
freebuff-manager runtime-check
```

`verify` treats an uncached native runtime as a valid installed-but-not-yet-bootstrapped state.


## Release finalization

Regenerate release metadata and run the full validation gate with:

```bash
bash qa/finalize-release.sh
```

The finalizer regenerates `MANIFEST.json` and `SHA256SUMS.txt` from the current
minimal repository before running the complete release validator.
