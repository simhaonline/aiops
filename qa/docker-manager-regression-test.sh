#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/docker-manager}"
[[ -f "$SCRIPT" ]] || { echo "missing: $SCRIPT" >&2; exit 1; }

extract_func(){
  local name="$1" next="$2"
  sed -n "/^${name}() {$/,/^${next}() {$/p" "$SCRIPT" | sed '$d'
}

body="$(extract_func write_host_daemon_config host_has_running_containers)"
[[ -n "$body" ]] || { echo 'write_host_daemon_config not found' >&2; exit 1; }
[[ "$body" != *'[[ -n "$backup" ]] && info "Host daemon config backup: $backup"'* ]]
[[ "$body" == *'if [[ -n "$backup" ]]; then'* ]]
[[ "$body" == *'return 0'* ]]

old_tail() {
  local backup=""
  [[ -n "$backup" ]] && echo "backup: $backup"
}

new_tail() {
  local backup=""
  if [[ -n "$backup" ]]; then
    echo "backup: $backup"
  fi
  return 0
}

set +e
old_tail
old_rc=$?
new_tail
new_rc=$?
set -e

echo "old_tail_rc=$old_rc"
echo "new_tail_rc=$new_rc"

[[ "$old_rc" -eq 1 ]]
[[ "$new_rc" -eq 0 ]]
bash -n "$SCRIPT"
bash "$SCRIPT" help >/dev/null

echo "DOCKER-MANAGER REGRESSION: PASS"
