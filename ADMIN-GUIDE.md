# SIMHA AiOps Administrator Operations Guide

Release `1.0.0` · Ubuntu Server 24.04 LTS

This guide is for administrators responsible for the host, shared services,
isolated project environments, source control, CI runners, security, backup,
restore, and operational verification.

## 1. Architecture and trust zones

Operate the platform as three distinct trust zones:

```text
Host infrastructure
├── system-manager
├── docker-manager
├── nginx-manager
├── wireguard-manager
├── forgejo-manager
└── optional shared Ollama

Project environments
├── one project-manager workspace per project
├── project source + AGENTS.md
├── isolated HOME and CODEX_HOME
├── isolated skills, plugins and MCP configuration
└── optional code-server, Goose, OpenCodex and MuleRouter access

CI execution plane
└── forgejo-runner-manager on a separate VM when possible
    └── dedicated user + dedicated rootless Podman socket
```

Never share a Docker/Podman socket, writable home directory, agent credentials,
or secret file between these zones.

## 2. Initial manager installation

For a checked-out repository:

```bash
bash ./install-canonical-managers.sh --check
sudo bash ./install-canonical-managers.sh all
manager-suite versions
manager-suite install-order
manager-suite dependencies
```

This installs manager commands only. It does not install or start their managed
runtimes.

Establish the host baseline first:

```bash
sudo system-manager install
sudo system-manager verify
```

Install rootless Docker before project environments or Forgejo:

```bash
sudo docker-manager install
sudo docker-manager verify
```

## 3. Shared Forgejo operations

Initialize and start Forgejo:

```bash
sudo forgejo-manager install
sudo forgejo-manager start
sudo forgejo-manager verify
```

The default service endpoints are loopback-only:

- HTTP: `127.0.0.1:3000`
- SSH: `127.0.0.1:2222`

Review the restricted environment file before deployment:

```text
/var/lib/docker-rootless/forgejo-stack/forgejo.env
```

Public registration is disabled. Create and approve users deliberately through
the Forgejo administration interface. Place the HTTP endpoint behind the
managed Nginx TLS edge before remote browser access. Only publish Forgejo SSH
when required; prefer VPN-restricted access.

Routine commands:

```bash
sudo forgejo-manager status
sudo forgejo-manager logs 200
sudo forgejo-manager restart
sudo forgejo-manager verify
```

Update only during a maintenance window:

```bash
sudo forgejo-manager update
```

`update` creates a backup first, pulls configured images, restarts the stack,
and verifies health. Major Forgejo upgrades require review of the upstream
migration notes and a tested rollback plan.

## 4. Forgejo Runner operations

Treat workflows as untrusted remote code. Install the runner on a separate VM
when contributors can modify repositories or workflow definitions.

Install an explicitly selected runner version:

```bash
sudo forgejo-runner-manager install RUNNER_VERSION
```

Create a repository- or organization-scoped runner in Forgejo. Then configure
it with the displayed UUID/token and a job image pinned by digest:

```bash
sudo forgejo-runner-manager configure \
  https://git.example.com/ \
  RUNNER_UUID \
  docker.io/library/node@sha256:FULL_DIGEST
```

The token is entered through a non-echoing prompt. Review the resulting file:

```text
/var/lib/forgejo-runner/runner-config.yml
```

Start and verify:

```bash
sudo forgejo-runner-manager start
sudo forgejo-runner-manager verify
sudo forgejo-runner-manager status
```

The manager rejects host labels, privileged execution, rootful Docker sockets,
and unpinned job images. Capacity is one to keep concurrent jobs from sharing
the same container engine.

Stop the runner immediately during a suspected workflow compromise:

```bash
sudo forgejo-runner-manager stop
sudo forgejo-runner-manager logs 500
```

Then rotate the runner token in Forgejo, inspect the runner VM, remove untrusted
images/containers, and restore only from a known-good configuration backup.

## 5. Project provisioning

Create projects under an administrator-approved parent directory:

```bash
sudo install -d -m 0755 /srv/projects
project-manager init /srv/projects/example example
project-manager verify /srv/projects/example
```

Review before the first build:

- `.aiops/project.env`
- `.aiops/container/Dockerfile`
- `.aiops/compose.yaml`
- `AGENTS.md`
- `.gitignore`

Start the environment:

```bash
project-manager up /srv/projects/example
project-manager status /srv/projects/example
```

Every project must use a unique `AIOPS_PROJECT_NAME`. Initialization allocates
an unused `AIOPS_CODE_SERVER_PORT` from `18080-18999` after checking sibling
managed projects and active listeners. Review the allocation before starting a
restored copy alongside its source project.

## 6. Optional project features

Enable only approved features:

```bash
project-manager feature-enable /srv/projects/example code-server
project-manager feature-enable /srv/projects/example goose
project-manager feature-enable /srv/projects/example opencodex
project-manager feature-enable /srv/projects/example mulerouter
```

Start code-server before publishing it, then create its managed TLS edge:

```bash
project-manager up /srv/projects/example
sudo project-manager edge-add /srv/projects/example code-server \
  ide.example.com admin@example.com projectadmin
project-manager edges /srv/projects/example
```

The command verifies the loopback health endpoint, creates an authenticated
Nginx WebSocket proxy, issues the certificate, verifies the site, and records
the association in `.aiops/features/code-server.edge`. Removal is intentionally
ordered so Nginx cannot retain an orphaned public route:

```bash
sudo project-manager edge-remove /srv/projects/example code-server
project-manager feature-disable /srv/projects/example code-server
```

Host services use their own edge helpers where applicable:

```bash
sudo nginx-manager harness-setup harness.example.com admin@example.com harnessadmin
sudo nginx-manager hermes-setup hermes.example.com admin@example.com hermesadmin
sudo codex-manager nginx-setup codex.example.com admin@example.com codexadmin
sudo opencode-manager nginx-setup opencode.example.com admin@example.com
sudo litellm-manager nginx-setup llm.example.com admin@example.com
sudo llmrouter-manager nginx-setup router.example.com admin@example.com
```

Codex uses edge Basic Auth and WebSocket forwarding. OpenCode preserves its
application Authorization header because it already generates native server
credentials. Claude, Goose and Freebuff are CLI tools and have no HTTP edge;
MuleRouter is an external provider; Ollama remains private on loopback.

Goose and OpenCodex require an explicit installation into the isolated project
home:

```bash
project-manager tool-install /srv/projects/example goose
project-manager tool-install /srv/projects/example opencodex
```

MuleRouter is an external provider. Use a separately scoped key for every
project:

```bash
project-manager secret-set /srv/projects/example mulerouter
```

Never commit `.aiops/home`, `.aiops/secrets`, `.aiops/backups`, or `.env`.

## 7. Backup policy

Maintain at least three copies of critical data, on two storage types, with one
copy offline or off-site. Encrypt archives before they leave trusted storage.

### Project backup

```bash
project-manager down /srv/projects/example
project-manager backup \
  /srv/projects/example \
  /srv/backups/projects/example.tar.gz
```

Project archives contain source, agent state, MCP definitions, skills, plugins,
credentials, IDE state, and other project-home data. Treat them as secrets.

### Forgejo backup

```bash
sudo forgejo-manager backup /srv/backups/forgejo/forgejo.tar.gz
```

The manager stops the Forgejo stack, snapshots both application and PostgreSQL
volumes, and restarts the stack if it was running. Monitor the maintenance
window and verify the generated `.sha256` sidecar.

### Runner registration backup

```bash
sudo forgejo-runner-manager backup \
  /srv/backups/runner/forgejo-runner.tar.gz
```

This archive contains the registration token. It does not contain disposable
job containers or caches.

### Backup verification

```bash
sha256sum -c /srv/backups/forgejo/forgejo.tar.gz.sha256
sha256sum -c /srv/backups/projects/example.tar.gz.sha256
```

Checksums detect corruption but do not provide authenticity or encryption.

## 8. Restore procedures

Test restores regularly on a non-production host.

### Restore a project

The destination must be absent or empty:

```bash
project-manager restore \
  /srv/backups/projects/example.tar.gz \
  /srv/projects/example-restored

project-manager verify /srv/projects/example-restored
project-manager up /srv/projects/example-restored
```

Assign different ports before starting the restored copy alongside production.

### Restore Forgejo

This replaces current Forgejo state:

```bash
sudo forgejo-manager restore \
  /srv/backups/forgejo/forgejo.tar.gz \
  --yes

sudo forgejo-manager verify
```

Afterward, test login, clone, fetch, push, LFS if used, issues, and Actions
registration. Do not rely on health status alone.

### Restore runner registration

```bash
sudo forgejo-runner-manager restore \
  /srv/backups/runner/forgejo-runner.tar.gz \
  --yes

sudo forgejo-runner-manager verify
```

The restore does not start the runner automatically. Review the endpoint, scope,
token, labels, image digest, and Podman socket before starting it.

## 9. Daily and weekly checks

Daily:

```bash
sudo manager-suite verify
sudo forgejo-manager status
sudo forgejo-runner-manager status
docker system df
df -h
```

Weekly:

- Review failed Forgejo Actions runs.
- Confirm backup completion and checksum verification.
- Review disk consumption for repositories, LFS, project homes and images.
- Review Forgejo administrators, tokens, runners and public repositories.
- Check pinned image and runtime versions for security updates.
- Run `project-manager verify` for active projects.

Monthly:

- Perform a restore drill.
- Rotate provider/runner credentials according to policy.
- Remove abandoned project environments only after a verified backup.
- Review firewall, Nginx, TLS and VPN access.

## 10. Safe removal

Stop a project without deleting state:

```bash
project-manager down /srv/projects/example
```

Remove project containers and isolated `.aiops` state while preserving source:

```bash
project-manager backup /srv/projects/example /srv/backups/example-final.tar.gz
project-manager destroy /srv/projects/example --yes
```

Do not manually delete Forgejo named volumes. Use a verified backup and an
approved decommission procedure.

## 11. Troubleshooting sequence

Use the narrowest relevant checks first:

```bash
manager-suite versions
sudo manager-suite verify
project-manager verify /srv/projects/example
project-manager status /srv/projects/example
sudo forgejo-manager status
sudo forgejo-manager logs 200
sudo forgejo-runner-manager status
sudo forgejo-runner-manager logs 200
```

Do not run mass repair, reinstall, purge, or restore operations as a first
response. Capture logs and back up current state before a material repair.

## 12. Change-control checklist

Before a production change:

1. Identify the affected trust zone.
2. Review the exact manager command and upstream version change.
3. Create and verify a backup.
4. Record current versions and health.
5. Define rollback and acceptance tests.
6. Apply the smallest scoped change.
7. Run manager verification and an application-level test.
8. Record the outcome and retain logs.
