# Installation Order - SIMHA AiOps 1.0.1

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

## Step 6 - Final health check

```bash
manager-suite versions
sudo manager-suite verify
```
