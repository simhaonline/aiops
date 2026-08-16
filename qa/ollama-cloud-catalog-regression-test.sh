#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/scripts/ollama-manager}"

bash -n "$SCRIPT"
output="$($SCRIPT cloud-catalog)"

expected=(
  glm-5.2:cloud kimi-k2.6:cloud kimi-k2.7-code:cloud minimax-m3:cloud
  qwen3.5:cloud qwen3.5:397b-cloud deepseek-v4-pro:cloud
  deepseek-v4-pro:preview-cloud deepseek-v4-flash:0731-cloud
  deepseek-v4-flash:preview-cloud gpt-oss:20b-cloud gpt-oss:120b-cloud
  mistral-large-3:675b-cloud gemma4:cloud gemma4:31b-cloud
  nemotron-3-ultra:cloud nemotron-3-super:cloud nemotron-3-nano:30b-cloud
)

for model in "${expected[@]}"; do
  grep -Fq "$model" <<<"$output"
done
[[ "$(grep -Ec '^  [[:space:]]*[0-9]+\)' <<<"$output")" -eq 18 ]]

grep -Fq 'Refusing model outside the approved Cloud catalog' "$SCRIPT"
grep -Fq 'install_cloud_models' "$SCRIPT"

(
  set -- help
  # shellcheck disable=SC1090
  source "$SCRIPT" >/dev/null
  is_cloud_proxy_model 'glm-5.2:cloud'
  is_cloud_proxy_model 'nemotron-3-nano:30b-cloud'
  ! is_cloud_proxy_model 'glm-5.2'
  ! is_cloud_proxy_model 'qwen3.5:397b'
)

echo 'OLLAMA CLOUD CATALOG REGRESSION: PASS'
