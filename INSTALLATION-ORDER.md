# Installation Order - SIMHA AiOps 1.0.0

## Step 0 - Install manager commands

```bash
curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh | bash
```

This step does not install runtimes.

## Step 1 - Base OS

```bash
sudo system-manager install
sudo system-manager verify
```

## Step 2 - Core runtimes

Install only what is required:

```bash
sudo docker-manager install
sudo forgejo-manager install       # optional shared Git service
# Install forgejo-runner-manager on its separate execution host/VM only.
sudo gvm-manager install
sudo miniconda-manager install
sudo nvm-manager install
```

## Step 3 - AI runtime / edge

```bash
sudo ollama-manager install
sudo nginx-manager install
# WireGuard only if required:
sudo wireguard-manager install
```

## Step 4 - AI agents

```bash
sudo harness-manager install
sudo hermes-manager install
sudo codex-manager install
sudo claude-manager install
sudo opencode-manager install
sudo freebuff-manager install
```

## Step 5 - AI gateways

```bash
sudo litellm-manager install
sudo llmrouter-manager install
```

Do not deploy both routing layers merely because both managers exist. Use the gateway/routing components needed by the architecture.

## Step 6 - Isolated development environments

Create these only for projects that need independent runtimes, skills, plugins,
MCP configuration, credentials, or agent state:

```bash
project-manager init /srv/projects/example example
project-manager up /srv/projects/example
```

## Step 7 - Optional isolated collections

```bash
collection-manager init /srv/projects/example documentation https://example.com/docs
collection-manager ui-enable /srv/projects/example
collection-manager crawl /srv/projects/example documentation
```

## Step 8 - Final health check

Optionally install the central operations UI before the final gate:

```bash
sudo aiops-dashboard-manager install /path/to/aiops/dashboard
sudo aiops-dashboard-manager verify
```

```bash
manager-suite versions
sudo manager-suite verify
```
