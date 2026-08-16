#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

require_fixed(){
  local file="$1" text="$2" message="$3"
  grep -Fq -- "$text" "$ROOT/scripts/$file" || {
    printf '[FAIL] %s: %s\n' "$file" "$message" >&2
    exit 1
  }
}

# Every maintained manager that can create a same-name Unix user/group must
# recover when the group already exists after a partial/previous install.
require_fixed system-manager 'if getent group "$user" >/dev/null 2>&1; then' \
  'admin account creation must detect an existing same-name group'
require_fixed system-manager 'args+=(--gid "$resolved_primary")' \
  'admin account creation must reuse an existing same-name group'

require_fixed docker-manager 'if getent group "$ROOTLESS_USER" >/dev/null 2>&1; then' \
  'rootless account creation must detect an existing same-name group'
require_fixed docker-manager 'useradd --create-home --home-dir "$ROOTLESS_HOME" --shell /bin/bash --gid "$ROOTLESS_USER" "$ROOTLESS_USER"' \
  'rootless account creation must reuse an existing same-name group'

require_fixed hermes-manager 'if getent group "$HERMES_GROUP" >/dev/null 2>&1; then' \
  'Hermes identity creation must detect an existing group'
require_fixed hermes-manager '--gid "$HERMES_GROUP"' \
  'Hermes identity creation must reuse the existing group'

require_fixed harness-manager 'if getent group "$HM_GROUP" >/dev/null 2>&1; then' \
  'Harness identity creation must detect an existing group'
require_fixed harness-manager '--gid "$HM_GROUP"' \
  'Harness identity creation must reuse the existing group'

require_fixed litellm-manager 'if getent group "$GROUP" >/dev/null 2>&1; then' \
  'LiteLLM identity creation must detect an existing group'
require_fixed litellm-manager '--gid "$GROUP"' \
  'LiteLLM identity creation must reuse the existing group'

require_fixed ollama-manager 'if getent group ollama >/dev/null 2>&1; then' \
  'Ollama identity creation must detect an existing group'
require_fixed ollama-manager 'useradd -r -s /bin/false -g ollama -m -d "$OLLAMA_SERVICE_HOME" ollama' \
  'Ollama identity creation must reuse the existing group'

echo 'ACCOUNT/GROUP COLLISION REGRESSION: PASS'

# Legacy support copies must carry the same partial-install protections because
# they are retained as usable fallback/support shell files.
LEGACY="$ROOT/legacy"

require_legacy_fixed(){
  local file="$1" text="$2" message="$3"
  grep -Fq -- "$text" "$LEGACY/$file" || {
    printf '[FAIL] legacy/%s: %s\n' "$file" "$message" >&2
    exit 1
  }
}

require_legacy_fixed system-manager.sh 'if getent group "$user" >/dev/null 2>&1; then' \
  'admin account creation must detect an existing same-name group'
require_legacy_fixed system-manager.sh 'args+=(--gid "$resolved_primary")' \
  'admin account creation must reuse an existing same-name group'

require_legacy_fixed docker-manager.sh 'if getent group "$ROOTLESS_USER" >/dev/null 2>&1; then' \
  'rootless account creation must detect an existing same-name group'
require_legacy_fixed docker-manager.sh '--gid "$ROOTLESS_USER"' \
  'rootless account creation must reuse the existing group'

require_legacy_fixed ollama-manager.sh 'if getent group ollama >/dev/null 2>&1; then' \
  'Ollama identity creation must detect an existing group'
require_legacy_fixed ollama-manager.sh '-g ollama' \
  'Ollama identity creation must reuse the existing group'

require_legacy_fixed harness-manager.sh 'if getent group "$HM_GROUP" >/dev/null 2>&1; then' \
  'Harness identity creation must detect an existing group'
require_legacy_fixed harness-manager.sh '--gid "$HM_GROUP"' \
  'Harness identity creation must reuse the existing group'

require_legacy_fixed hermes-manager.sh 'if getent group "$HERMES_GROUP" >/dev/null 2>&1; then' \
  'Hermes identity creation must detect an existing group'
require_legacy_fixed hermes-manager.sh '--gid "$HERMES_GROUP"' \
  'Hermes identity creation must reuse the existing group'

require_legacy_fixed litellm-manager.sh 'if getent group "$GROUP" >/dev/null 2>&1; then' \
  'LiteLLM identity creation must detect an existing group'
require_legacy_fixed litellm-manager.sh '--gid "$GROUP"' \
  'LiteLLM identity creation must reuse the existing group'

echo 'LEGACY ACCOUNT/GROUP COLLISION REGRESSION: PASS'
