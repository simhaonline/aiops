# SIMHA AiOps User Operations Guide

Release `1.0.0`

This guide is for developers using an administrator-provisioned SIMHA AiOps
host. It covers daily work inside isolated project environments. Host, Forgejo,
Nginx, firewall, runner, and shared-service administration remain administrator
responsibilities.

## 1. What project isolation provides

Every managed project has its own:

- Source directory and `AGENTS.md`
- Container image and runtime packages
- Linux home directory
- Codex home and configuration
- Skills and plugins
- MCP server definitions
- Agent sessions, caches and settings
- Optional browser IDE
- Optional Goose and OpenCodex installations
- Optional MuleRouter credential

Nothing in `.aiops/home` is shared with another project unless someone
deliberately changes the generated mounts.

## 2. Create or open a project

Create a new project:

```bash
project-manager init /srv/projects/example example
cd /srv/projects/example
```

Review the generated files:

```text
AGENTS.md
.gitignore
.aiops/project.env
.aiops/container/Dockerfile
.aiops/compose.yaml
```

Start and enter the workspace:

```bash
project-manager up
project-manager shell
```

From another directory, provide the project path:

```bash
project-manager shell /srv/projects/example
```

## 3. Define project requirements

Put repository-wide working instructions in `AGENTS.md`. Include:

- Project purpose and architecture
- Supported runtime versions
- Build, format, lint and test commands
- Security boundaries
- Files that must not be changed
- Required review or verification steps
- Rules for project-specific skills and MCP servers

Edit `.aiops/container/Dockerfile` for system/runtime dependencies and
`.aiops/project.env` for supported build settings. Rebuild after changing them:

```bash
project-manager build
project-manager up
```

Use application lock files such as `package-lock.json`, `uv.lock`,
`requirements.txt`, `poetry.lock`, `go.mod`, or `Cargo.lock` so another user can
reproduce the same environment.

## 4. Project-specific Codex, skills, plugins and MCP

The container sets:

```text
HOME=/home/developer
CODEX_HOME=/home/developer/.codex
```

Project-specific Codex state is persisted on the host under:

```text
.aiops/home/.codex/
```

Store project-only skills under:

```text
.aiops/home/.codex/skills/
```

Plugin and MCP configuration should remain under the project’s Codex home or
other project-home configuration paths. Do not symlink these directories to a
host-global home or another project.

Authenticate tools separately inside each project when different projects need
different accounts, permissions, providers, or billing boundaries.

## 5. Run commands

Open an interactive shell:

```bash
project-manager shell /srv/projects/example
```

Run one command without opening a shell:

```bash
project-manager run /srv/projects/example -- npm test
project-manager run /srv/projects/example -- python3 -m pytest
```

View project status:

```bash
project-manager status /srv/projects/example
project-manager verify /srv/projects/example
```

Stop the environment when it is not needed:

```bash
project-manager down /srv/projects/example
```

Stopping containers preserves source and project-home state.

## 6. Browser IDE with code-server

Enable code-server:

```bash
project-manager feature-enable /srv/projects/example code-server
project-manager up /srv/projects/example
```

The default address is:

```text
http://127.0.0.1:8080
```

If another project already uses that port, change
`AIOPS_CODE_SERVER_PORT` in `.aiops/project.env`, then restart the project.

The generated password is stored at:

```text
.aiops/secrets/code-server.env
```

Do not send that file through chat, commit it, or paste it into an issue. For
remote browser access, use the administrator-provided HTTPS address or VPN; do
not change the bind address to `0.0.0.0` yourself.

Disable the feature while preserving its settings:

```bash
project-manager feature-disable /srv/projects/example code-server
```

## 7. Goose

Enable and install Goose inside this project only:

```bash
project-manager feature-enable /srv/projects/example goose
project-manager tool-install /srv/projects/example goose
project-manager shell /srv/projects/example
goose configure
```

Add only the MCP servers required by this project. Review every MCP server’s
commands, filesystem access, network access, credentials, and data destination
before enabling it.

## 8. OpenCodex

This integration uses the `@bitkyc08/opencodex` provider proxy:

```bash
project-manager feature-enable /srv/projects/example opencodex
project-manager tool-install /srv/projects/example opencodex
project-manager shell /srv/projects/example
ocx init
```

Provider accounts and routing state remain in the project home. Keep the proxy
on loopback. Do not enable LAN hosting without administrator review, unique
data-plane/admin credentials, and a documented need.

## 9. MuleRouter

MuleRouter is an external provider, not a local service. Request or create a
separate key for this project, then enter it through the protected prompt:

```bash
project-manager feature-enable /srv/projects/example mulerouter
project-manager secret-set /srv/projects/example mulerouter
```

The key is stored in `.aiops/secrets/runtime.env` and injected into the project
workspace as `MULEROUTER_API_KEY`. Never place the value in `AGENTS.md`, source
files, Git configuration, screenshots, logs, or shell history.

## 10. Forgejo workflow

Use the Forgejo URL provided by the administrator. Clone a repository into a
new or approved project directory:

```bash
git clone https://git.example.com/OWNER/REPOSITORY.git /srv/projects/example
project-manager init /srv/projects/example example
```

For an existing initialized project:

```bash
cd /srv/projects/example
git status
git pull --ff-only
project-manager up
```

Keep workflow definitions under `.forgejo/workflows/`. Remember that workflows
run code on the CI runner. Never print secrets, request privileged containers,
mount host paths, or assume GitHub-specific behavior without testing.

## 11. Back up your project

Stop stateful workloads first when consistency matters:

```bash
project-manager down /srv/projects/example
project-manager backup \
  /srv/projects/example \
  /srv/backups/example.tar.gz
```

The backup contains source and private project state, including credentials.
Protect it as sensitive data. Verify its checksum:

```bash
sha256sum -c /srv/backups/example.tar.gz.sha256
```

## 12. Restore your project

Restore only into an absent or empty directory:

```bash
project-manager restore \
  /srv/backups/example.tar.gz \
  /srv/projects/example-restored

project-manager verify /srv/projects/example-restored
```

Before starting a restored copy alongside the original, change its project name
and any published ports to avoid collisions. Ask an administrator if the copy
contains services, databases, or shared-provider credentials.

## 13. Common problems

### No managed project found

Run the command inside the project tree or provide its path:

```bash
project-manager status /srv/projects/example
```

### Port already allocated

Another project is probably using the same published port. Change the relevant
port in `.aiops/project.env` and restart.

### Permission denied in the workspace

Do not run development commands with `sudo` inside the container. Ask the
administrator to verify the project UID/GID mapping and ownership.

### Tool configuration appears to be missing

Confirm that you entered the correct project. Each project intentionally has a
different home/configuration directory.

### Build stopped after dependency changes

Capture the failing build output and review the Dockerfile or lock files. Do not
install the dependency globally on the host as a workaround.

## 14. User safety checklist

- Confirm the project path before running an agent.
- Read `AGENTS.md` before making changes.
- Keep secrets out of Git and prompts unless explicitly required.
- Review project-specific MCP and plugin permissions.
- Do not mount Docker/Podman sockets into a project.
- Do not publish project ports directly to the Internet.
- Run tests before pushing changes.
- Back up before major dependency, agent, or configuration changes.
- Stop and report unexpected access to other projects or host files.

