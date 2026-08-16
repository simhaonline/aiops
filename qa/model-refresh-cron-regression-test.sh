#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
AIOPS="$ROOT/scripts/aiops"
OLLAMA="$ROOT/scripts/ollama-manager"
LITELLM="$ROOT/scripts/litellm-manager"

for script in "$AIOPS" "$OLLAMA" "$LITELLM"; do bash -n "$script"; done

grep -Fq 'sync-free-models nvidia' "$AIOPS"
grep -Fq 'sync-free-models openrouter' "$AIOPS"
grep -Fq 'sync-cloud' "$AIOPS"
grep -Fq "cron_schedule='17 3 * * *'" "$AIOPS"
grep -Fq "cron_schedule='17 3 * * 0'" "$AIOPS"
grep -Fq 'root /usr/local/bin/aiops model-refresh' "$AIOPS"
grep -Fq 'install -o root -g root -m 0644' "$AIOPS"
grep -Fq 'install_cloud_models "${CLOUD_PROXY_MODELS[@]}"' "$OLLAMA"
grep -Fq 'No verified free models returned; configuration unchanged.' "$LITELLM"

echo 'MODEL REFRESH CRON REGRESSION: PASS'
