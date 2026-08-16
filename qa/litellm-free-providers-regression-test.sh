#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/scripts/litellm-manager}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

bash -n "$SCRIPT"
set -- help
# shellcheck disable=SC1090
source "$SCRIPT" >/dev/null

cat >"$TMP/openrouter.json" <<'JSON'
{"data":[
 {"id":"vendor/free:free","pricing":{"prompt":"0","completion":"0","request":"0","image":"0"}},
 {"id":"vendor/paid","pricing":{"prompt":"0.1","completion":"0","request":"0"}},
 {"id":"vendor/deceptive:free","pricing":{"prompt":"0","completion":"0.2","request":"0"}},
 {"id":"vendor/missing:free","pricing":{"prompt":"0","completion":"0"}}
]}
JSON
[[ "$(parse_openrouter_free_models "$TMP/openrouter.json")" == 'vendor/free:free' ]]

cat >"$TMP/nvidia.json" <<'JSON'
{"data":[
 {"id":"z-ai/glm-5.2"},
 {"id":"nvidia/nemotron-3-ultra-550b-a55b"},
 {"id":"vendor/unverified-paid-model"}
]}
JSON
output="$(parse_nvidia_free_models "$TMP/nvidia.json")"
grep -Fq 'z-ai/glm-5.2' <<<"$output"
grep -Fq 'nvidia/nemotron-3-ultra-550b-a55b' <<<"$output"
[[ "$output" != *unverified-paid-model* ]]

grep -Fq 'OPENROUTER_API_KEY' "$SCRIPT"
grep -Fq 'NVIDIA_NIM_API_KEY' "$SCRIPT"
grep -Fq '"api_key": "os.environ/"' "$SCRIPT"
grep -Fq 'No verified free models returned; configuration unchanged.' "$SCRIPT"
echo 'LITELLM FREE PROVIDERS REGRESSION: PASS'
