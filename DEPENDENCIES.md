# Dependency Map - SIMHA AiOps 1.0.1

## Host requirement

- Ubuntu Server 24.04 LTS
- amd64/x86_64 is the primary validated architecture for the current suite
- root or sudo for manager installation and runtime mutations

## Dependency sequence

1. `system-manager` - base package/security policy.
2. `docker-manager`, `gvm-manager`, `miniconda-manager`, `nvm-manager` - core runtimes.
3. `ollama-manager`, `nginx-manager`, `wireguard-manager` - AI runtime/edge/network.
4. `harness-manager` - requires `nvm-manager` for Node and `ollama-manager` for the configured Ollama provider.
5. `hermes-manager` - uses system build dependencies; Nginx optional.
6. `codex-manager`, `claude-manager` - independent coding-agent runtimes.
7. `opencode-manager`, `freebuff-manager`, `llmrouter-manager` - require NVM/Node.
8. `litellm-manager` - Python/venv based; Nginx optional.
9. `manager-suite` - cross-manager health/inventory.

## Shared services

`nginx-manager` is optional unless an application needs a public HTTPS edge. Backends should remain loopback-only.

`manager-suite` is always safe to install; it does not install runtimes.
