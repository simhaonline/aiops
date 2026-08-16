#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${1:-$ROOT/scripts/aiops}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for manager in system-manager docker-manager forgejo-manager forgejo-runner-manager gvm-manager miniconda-manager nvm-manager ollama-manager nginx-manager wireguard-manager harness-manager hermes-manager codex-manager claude-manager opencode-manager freebuff-manager litellm-manager llmrouter-manager project-manager collection-manager aiops-dashboard-manager; do
  ln -s /bin/true "$TMP/$manager"
done

bash -n "$SCRIPT"
output="$($SCRIPT help)"; grep -Fq 'unified CLI' <<<"$output"
output="$($SCRIPT version)"; grep -Fq 'aiops 1.0.0' <<<"$output"
output="$(PATH="$TMP:/usr/bin:/bin" "$SCRIPT" list)"; grep -Fq 'aiops-dashboard-manager' <<<"$output"
output="$(PATH="$TMP:/usr/bin:/bin" "$SCRIPT" run docker-manager -- status)"; grep -Fq 'docker-manager: ' <<<"$output"
output="$(PATH="$TMP:/usr/bin:/bin" "$SCRIPT" run --phase agents --dry-run -- verify)"; grep -Fq 'codex-manager: ' <<<"$output"

if PATH="$TMP:/usr/bin:/bin" "$SCRIPT" run --all -- update >/dev/null 2>&1; then
  echo 'bulk mutation unexpectedly succeeded without --yes' >&2
  exit 1
fi
output="$(PATH="$TMP:/usr/bin:/bin" "$SCRIPT" run --all --yes --dry-run -- update)"; grep -Fq 'system-manager: ' <<<"$output"

literal='$(touch /tmp/simha-runtime-must-not-exist)'
PATH="$TMP:/usr/bin:/bin" "$SCRIPT" run docker-manager -- status "$literal" >/dev/null
[[ ! -e /tmp/simha-runtime-must-not-exist ]]

echo 'AIOPS CLI REGRESSION: PASS'
