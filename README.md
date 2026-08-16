# SIMHA AiOps Manager Suite

**Release:** `1.0.1`  
**Target OS:** Ubuntu Server 24.04 LTS  
**Repository:** `simhaonline/aiops`

Simha AiOps is a production-oriented collection of lifecycle managers for operating an AI development/inference server without mixing every runtime into one monolithic installer.

The maintained manager scripts are in `scripts/`. The files in `legacy/` are support snapshots only and are **never executed automatically**.

## Quick install

The supported one-line bootstrap is:

```bash
curl -fsSL [https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh](https://raw.githubusercontent.com/simhaonline/Simha-AiOps/refs/heads/main/install.sh) | bash
```

This command:

1. requires Ubuntu 24.04 LTS for install mode;
2. resolves `main` (or the requested tag) to one immutable Git commit before downloading the release payload;
3. downloads `SHA256SUMS.txt` from that exact commit;
4. downloads all **17** maintained manager scripts from the same commit;
5. verifies every downloaded manager against the checksum manifest;
6. runs Bash syntax, `help`, and version checks;
7. backs up existing canonical manager commands;
8. installs 16 managers to `/usr/local/bin`;
9. installs `wireguard-manager` to `/usr/local/sbin`;
10. skips `legacy/` by default so support snapshots can never block a normal installation;
11. writes an installer log under `/var/log/simha-aiops/`.

**The bootstrap installs manager scripts only. It does not automatically install, repair, start, restart, update, or purge the managed runtimes.**

That separation is intentional: installing manager commands is low risk; runtime installation can modify packages, services, firewall policy, credentials, or application state and therefore remains explicit.

### Reproducible production install

`main` is mutable. For repeatable production deployment, pin a release tag or commit:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/simhaonline/aiops/v1.0.1/install.sh \
  | AIOPS_REF=v1.0.1 AIOPS_REQUIRE_PIN=1 bash
```

You can also perform a download/verification-only bootstrap test:

```bash
curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh \
  | AIOPS_DRY_RUN=1 bash
```

## Maintained managers

| Manager | Version | Purpose | Primary dependency |
|---|---:|---|---|
| `system-manager` | 1.0.1 | Ubuntu base security/packages/SSH/UFW/limits/time | Ubuntu 24.04 |
| `docker-manager` | 1.0.1 | Host Docker + managed rootless Docker | system baseline recommended |
| `gvm-manager` | 1.0.1 | Root-scoped GVM/Go | system baseline recommended |
| `miniconda-manager` | 1.0.1 | System-wide Miniconda | system baseline recommended |
| `nvm-manager` | 1.0.1 | Root NVM/Node/PM2 | system baseline recommended |
| `ollama-manager` | 1.0.1 | Ollama Cloud/local loopback API policy | system baseline recommended |
| `nginx-manager` | 1.0.1 | Nginx/Certbot reverse proxy and TLS | system baseline recommended |
| `wireguard-manager` | 1.0.1 | WireGuard VPN | system baseline recommended |
| `harness-manager` | 1.0.1 | DeepSeek Harness CLI/Web service | **requires `nvm-manager` and `ollama-manager`** |
| `hermes-manager` | 1.0.1 | Hermes CLI + loopback Dashboard | system build packages |
| `codex-manager` | 1.0.1 | OpenAI Codex CLI/App Server lifecycle | system base utilities |
| `claude-manager` | 1.0.1 | Claude Code lifecycle | system base utilities |
| `opencode-manager` | 1.0.1 | OpenCode CLI/server lifecycle | **requires `nvm-manager`** |
| `freebuff-manager` | 1.0.1 | Freebuff CLI lifecycle | **requires `nvm-manager`** |
| `litellm-manager` | 1.0.1 | LiteLLM Proxy lifecycle | Python/venv/build baseline |
| `llmrouter-manager` | 1.0.1 | LMRouter CLI/API lifecycle | **requires `nvm-manager`** |
| `manager-suite` | 1.0.1 | Cross-manager inventory/status/verification | none |

Runtime/upstream application versions are independent from the manager suite version. For example, `nvm-manager 1.0.1` can manage a newer Node release without changing the manager's own version.

## Recommended runtime installation sequence

The bootstrap above installs all manager **commands** in one operation. When installing actual runtimes, use this order:

```text
Phase 1 - Base OS
  1. system-manager

Phase 2 - Core runtimes
  2. docker-manager
  3. gvm-manager
  4. miniconda-manager
  5. nvm-manager

Phase 3 - AI runtime and edge
  6. ollama-manager
  7. nginx-manager
  8. wireguard-manager

Phase 4 - AI agents
  9. harness-manager
 10. hermes-manager
 11. codex-manager
 12. claude-manager
 13. opencode-manager
 14. freebuff-manager

Phase 5 - AI gateways/routing
 15. litellm-manager
 16. llmrouter-manager

Phase 6 - Health gate
 17. manager-suite
```

Display the same sequence from the installed suite:

```bash
manager-suite install-order
manager-suite dependencies
```

You do **not** have to install every runtime. Install only the components the server actually needs.

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

Legacy support snapshots are intentionally skipped by default. To validate and copy them read-only:

```bash
sudo AIOPS_INSTALL_LEGACY=1 bash ./install-canonical-managers.sh all
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

Individual managers may maintain their own logs, state directories, and backups. See the manager reference documents in `docs/`.

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
- `legacy/` files are reference material, not trusted current executables.

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

## Legacy support directory

The repository keeps:

```text
legacy/
```

for migration/rollback reference. These files are not canonical managers and are not placed on executable PATH. They are **not copied by the normal bootstrap**. If explicitly requested with `AIOPS_INSTALL_LEGACY=1`, they are copied read-only to:

```text
/usr/local/share/simha-aiops/legacy/
```

Do not execute a legacy manager in production without reviewing the older behavior first.

## Repository layout

```text
.
├── .github/workflows/validate.yml
├── scripts/                 # 17 maintained executable managers
├── legacy/                  # non-executable support snapshots
├── docs/                    # 19 current reference documents
├── qa/                      # release validation/regression checks
├── README.md
├── ABOUT.md
├── DEPENDENCIES.md
├── INSTALLATION-ORDER.md
├── SECURITY.md
├── RELEASE-NOTES.md
├── MANIFEST.json
├── QA-REPORT.txt
├── SHA256SUMS.txt
├── install.sh
├── install-canonical-managers.sh
└── sync-github-repo.sh
```

## Release validation

Before publishing:

```bash
bash qa/validate-release.sh
```

The release gate checks:

- exactly 17 maintained manager scripts;
- all maintained managers are version `1.0.1`;
- Bash syntax;
- manager `help` entry points;
- canonical installer `--check`;
- checksums;
- repository inventory;
- DOCX package integrity;
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

SIMHA AiOps Manager Suite `1.0.1`


## Freebuff first-run runtime

`freebuff-manager install` verifies the npm launcher and canonical wrapper without hiding a first-run network failure. The native Freebuff runtime is downloaded separately by the upstream launcher:

```bash
sudo freebuff-manager install
sudo freebuff-manager bootstrap
freebuff-manager runtime-check
```

`verify` treats an uncached native runtime as a valid installed-but-not-yet-bootstrapped state.


## Release finalization

The `docs/` directory is release-managed and must contain exactly 19 canonical DOCX references.
If historical generations remain after an older manual upload, clean and rebuild the release metadata with:

```bash
bash qa/finalize-release.sh
```

The finalizer runs `qa/cleanup-docs.sh`, removes only non-canonical `docs/*.docx` files, verifies all 19 required documents remain, then regenerates `MANIFEST.json` and `SHA256SUMS.txt` before running the complete release validator.
