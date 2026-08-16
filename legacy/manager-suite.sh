#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'

readonly SUITE_VERSION="2026.08.16-r3.1"
readonly MANAGERS=(
  system-manager
  docker-manager
  gvm-manager
  miniconda-manager
  nvm-manager
  ollama-manager
  harness-manager
  nginx-manager
  wireguard-manager
  hermes-manager
  codex-manager
  claude-manager
  opencode-manager
  freebuff-manager
  litellm-manager
  llmrouter-manager
)

say(){ printf '%-22s %s\n' "$1" "$2"; }

runtime_present() {
  case "$1" in
    system-manager) [[ -r /var/lib/simha-system-manager/config ]] ;;
    docker-manager) command -v docker >/dev/null 2>&1 ;;
    gvm-manager) [[ -s /root/.gvm/scripts/gvm ]] ;;
    miniconda-manager) [[ -x /opt/miniconda3/bin/conda ]] ;;
    nvm-manager) [[ -s /root/.nvm/nvm.sh ]] ;;
    ollama-manager) command -v ollama >/dev/null 2>&1 ;;
    harness-manager) [[ -d /opt/deepseek-harness/app && -f /etc/systemd/system/deepseek-harness.service ]] ;;
    nginx-manager) command -v nginx >/dev/null 2>&1 ;;
    wireguard-manager) [[ -f /etc/wireguard/wg0.conf ]] ;;
    hermes-manager) [[ -d /var/lib/hermes-agent/.hermes ]] ;;
    codex-manager) [[ -x /root/.local/bin/codex ]] ;;
    claude-manager) command -v claude >/dev/null 2>&1 ;;
    opencode-manager) [[ -x /root/.nvm/default-bin/opencode ]] ;;
    freebuff-manager) [[ -x /root/.nvm/default-bin/freebuff ]] ;;
    litellm-manager) [[ -x /opt/litellm/current/bin/litellm ]] ;;
    llmrouter-manager) [[ -x /root/.nvm/default-bin/lmrouter ]] ;;
    *) return 1 ;;
  esac
}

manager_version() {
  local m="$1"
  case "$m" in
    nvm-manager|ollama-manager) "$m" manager-version 2>/dev/null | head -2 || true ;;
    *) "$m" version 2>/dev/null | head -2 || true ;;
  esac
}

versions() {
  echo "SIMHA Manager Suite $SUITE_VERSION"
  local m out
  for m in "${MANAGERS[@]}"; do
    if ! command -v "$m" >/dev/null 2>&1; then
      say "$m" "MANAGER NOT INSTALLED"
      continue
    fi
    out="$(manager_version "$m")"
    if runtime_present "$m"; then
      say "$m" "${out//$'\n'/ | }"
    else
      say "$m" "manager installed; runtime not installed${out:+ | ${out//$'\n'/ | }}"
    fi
  done
}

verify() {
  local strict="${1:-no}" failed=0 m
  for m in "${MANAGERS[@]}"; do
    if ! command -v "$m" >/dev/null 2>&1; then
      if [[ "$strict" == yes ]]; then say "$m" "FAILED (manager missing)"; failed=1; else say "$m" "SKIP (manager missing)"; fi
      continue
    fi
    if ! runtime_present "$m"; then
      if [[ "$strict" == yes ]]; then say "$m" "FAILED (runtime missing)"; failed=1; else say "$m" "SKIP (runtime not installed)"; fi
      continue
    fi
    if "$m" verify >"/tmp/manager-suite-${m}.log" 2>&1; then
      say "$m" "VERIFIED"
    else
      say "$m" "FAILED"
      sed -n '1,100p' "/tmp/manager-suite-${m}.log"
      failed=1
    fi
  done
  rm -f /tmp/manager-suite-*.log
  (( failed == 0 ))
}

status() {
  versions
  echo
  local m
  for m in "${MANAGERS[@]}"; do
    command -v "$m" >/dev/null 2>&1 || continue
    runtime_present "$m" || continue
    echo "===== $m ====="
    "$m" status 2>&1 | sed -n '1,40p' || true
    echo
  done
}

help() {
  cat <<EOF2
manager-suite $SUITE_VERSION

Commands:
  versions     Show manager/runtime versions
  verify       Verify only runtimes that are actually installed
  verify-all   Strict verification; missing manager/runtime is a failure
  status       Concise status for installed runtimes
  help
EOF2
}

case "${1:-help}" in
  versions|version) versions ;;
  verify) verify no ;;
  verify-all) verify yes ;;
  status) status ;;
  help|-h|--help) help ;;
  *) help; exit 2 ;;
esac
