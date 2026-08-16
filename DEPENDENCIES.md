# Dependency Map - SIMHA AiOps 1.0.0

## Host requirement

- Ubuntu Server 24.04 LTS
- amd64/x86_64 is the primary validated architecture for the current suite
- root or sudo for manager installation and runtime mutations

## Dependency sequence

1. `system-manager` - base package/security policy.
2. `docker-manager`, `gvm-manager`, `miniconda-manager`, `nvm-manager` - core runtimes.
3. `forgejo-manager` - requires the dedicated rootless Docker daemon.
4. `forgejo-runner-manager` - independent rootless Podman execution plane; separate VM recommended.
5. `ollama-manager`, `nginx-manager`, `wireguard-manager` - AI runtime/edge/network.
6. `harness-manager` - requires `nvm-manager` for Node and `ollama-manager` for the configured Ollama provider.
7. `hermes-manager` - uses system build dependencies; Nginx optional.
8. `codex-manager`, `claude-manager` - independent coding-agent runtimes.
9. `opencode-manager`, `freebuff-manager`, `llmrouter-manager` - require NVM/Node.
10. `litellm-manager` - Python/venv based; Nginx optional.
11. `project-manager` - Docker Compose based, isolated per-project development.
12. `collection-manager` - requires `project-manager` and Docker; isolated Scrapling collection workers.
13. `aiops-dashboard-manager` - Docker, Python 3 and repository dashboard source; Nginx optional.
14. `manager-suite` - cross-manager health/inventory.

## Shared services

`nginx-manager` is optional unless an application needs a public HTTPS edge. Backends should remain loopback-only.

`manager-suite` is always safe to install; it does not install runtimes.

`project-manager` requires Docker with the Compose plugin. It creates a separate
home/configuration mount and Compose network for every project.

`collection-manager` stores collection policy and data inside the selected
project, uses a pinned Scrapling image, and can publish its loopback dashboard
through `nginx-manager`.

`aiops-dashboard-manager` builds the Next.js and NestJS containers with Node
22, compiles the Go broker in a pinned Go container, and runs dependency-free
Python telemetry as an unprivileged systemd service. The dashboard includes the
native SIMHA Studio UI and capability API for text, codebases, documents,
image, video, voice, translation, workflows, projects, registry assets, and
operations. See `ARCHITECTURE-REPORT.md` for the request lifecycle and current
backend delivery boundary.
