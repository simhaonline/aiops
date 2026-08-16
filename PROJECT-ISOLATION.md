# Isolated Project Development

`project-manager` creates one Docker Compose workspace per project. Its purpose
is to prevent unrelated projects from sharing runtimes, home-directory state,
Codex configuration, MCP servers, skills, plugins, credentials, caches, or agent
history.

## Create a project

```bash
project-manager init /srv/projects/example example
cd /srv/projects/example
project-manager build
project-manager up
project-manager shell
```

The generated project contains:

```text
example/
├── AGENTS.md
├── .gitignore
└── .aiops/
    ├── compose.yaml
    ├── project.env
    ├── container/Dockerfile
    ├── home/
    │   ├── .codex/
    │   │   ├── skills/
    │   │   └── plugins/
    │   └── .config/
    └── backups/
```

`.aiops/home` becomes `/home/developer` inside the container and `CODEX_HOME`
is fixed to `/home/developer/.codex`. Consequently, every project receives its
own Codex configuration and MCP definitions, plus its own skills and plugins.
Other tools that follow `HOME` or XDG conventions are isolated by the same home
mount. `AGENTS.md` remains in the project root so instructions travel with the
project when committed.

The generated container does not mount the host Docker socket, `/root`, or a
host-global Codex directory. It runs as an unprivileged user with all Linux
capabilities dropped and `no-new-privileges` enabled.

The generated account maps the invoking user's UID and GID. If initialization
is run as root, it deliberately uses unprivileged `10000:10000`; set
`AIOPS_PROJECT_UID` and `AIOPS_PROJECT_GID` during `init` to override this.

## Customize dependencies

Edit `.aiops/project.env` to change the Ubuntu base image or initial APT package
set. For more involved requirements, edit `.aiops/container/Dockerfile` and
commit that file with the project. Install application dependencies through the
project's own lock files rather than a host-global package installation.

Do not commit `.aiops/home`, `.aiops/backups`, `.env`, tokens, or private keys.
The generated `.gitignore` excludes these paths by default.

## Optional project features

Enable only what a project needs:

```bash
project-manager feature-enable /srv/projects/example code-server
project-manager feature-enable /srv/projects/example goose
project-manager feature-enable /srv/projects/example opencodex
project-manager feature-enable /srv/projects/example mulerouter
project-manager features /srv/projects/example
```

code-server runs as a project sidecar, uses the same isolated source/home mounts,
binds to `127.0.0.1`, and receives a unique generated password. Change
`AIOPS_CODE_SERVER_PORT` in `.aiops/project.env` when several projects run at
once. Place Nginx authentication or SSO in front before remote access.

Goose and OpenCodex are installed into the running workspace only after an
explicit request:

```bash
project-manager tool-install /srv/projects/example goose
project-manager tool-install /srv/projects/example opencodex
```

Goose configuration and MCP definitions remain under the isolated project
home. This OpenCodex integration targets the `@bitkyc08/opencodex` provider
proxy; its accounts and routing state remain under the same project boundary.

MuleRouter is a hosted provider, not a local runtime. Store a separate key for
each project through the non-echoing prompt:

```bash
project-manager secret-set /srv/projects/example mulerouter
```

The key is injected through `.aiops/secrets/runtime.env`; it is never added to
the image or `project.env`.

## Backup and restore

Backups contain the complete project source and its isolated home/configuration
state:

```bash
project-manager backup /srv/projects/example /srv/backups/example.tar.gz
project-manager restore /srv/backups/example.tar.gz /srv/projects/example-restored
project-manager verify /srv/projects/example-restored
```

Backup archives and checksum sidecars are mode `0600`. Restore verifies the
sidecar when present, rejects absolute or parent-traversal archive paths, and
only writes into an absent or empty destination. Stop database or other
stateful services before backup when application-level consistency is needed.
Because the archive contains `.aiops/home` and `.aiops/secrets`, it must be
treated as a secret-bearing artifact and encrypted by the operator whenever it
leaves trusted storage.

## Boundaries

- Docker images may share immutable layers for storage efficiency; writable
  container state, project homes, Compose networks, and source trees are
  separate.
- Credentials are intentionally not imported from the host. Authenticate tools
  separately in each project or inject narrowly scoped secrets at runtime.
- The workspace has outbound network access by default. Restrict or disable it
  in `compose.yaml` when a project's threat model requires that.
- A shared host Ollama can be exposed deliberately, but it is not added to a
  project automatically.
