#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

# claude-manager v1.0.0
# Ubuntu 24.04 LTS
# Anthropic Claude Code using the official signed APT repository.

readonly MANAGER_VERSION="1.0.0"
readonly MANAGER_PATH="/usr/local/bin/claude-manager"
readonly LOCK_FILE="/run/lock/claude-manager.lock"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
on_error() { local rc=$?; printf '[ERROR] Command failed at line %s (exit %s).\n' "${BASH_LINENO[0]:-?}" "$rc" >&2; exit "$rc"; }
trap on_error ERR
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."; }
require_ubuntu() { [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."; . /etc/os-release; [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || die "Ubuntu 24.04 LTS required."; }
lock() { install -d -m 0755 /run/lock; exec 9>"$LOCK_FILE"; flock -w 120 9 || die "Another claude-manager operation is active."; }
self_install() { local s; s="$(readlink -f "${BASH_SOURCE[0]}")"; if [[ "$s" != "$MANAGER_PATH" ]]; then install -o root -g root -m 0755 "$s" "$MANAGER_PATH"; fi; }
begin() { require_root; require_ubuntu; lock; self_install; }

readonly KEYRING="/etc/apt/keyrings/claude-code.asc"
readonly SOURCE="/etc/apt/sources.list.d/claude-code.list"
readonly EXPECTED_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
readonly DATA_DIR="/root/.claude"
readonly CHANNEL_FILE="/etc/claude-manager.channel"

install_deps() { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl gnupg; install -d -m 0755 /etc/apt/keyrings; }
channel() { cat "$CHANNEL_FILE" 2>/dev/null || echo stable; }
set_repo() {
  local ch="${1:-stable}" t fpr
  [[ "$ch" == stable || "$ch" == latest ]] || die "Channel must be stable or latest."
  t="$(mktemp /tmp/claude-key.XXXXXX)"
  curl -fsSL --proto '=https' --tlsv1.2 https://downloads.claude.ai/keys/claude-code.asc -o "$t"
  fpr="$(gpg --show-keys --with-colons "$t" | awk -F: '$1=="fpr"{print $10; exit}')"
  [[ "$fpr" == "$EXPECTED_FPR" ]] || die "Claude signing-key fingerprint mismatch: $fpr"
  install -o root -g root -m 0644 "$t" "$KEYRING"; rm -f "$t"
  printf 'deb [signed-by=%s] https://downloads.claude.ai/claude-code/apt/%s %s main\n' "$KEYRING" "$ch" "$ch" >"$SOURCE"
  printf '%s\n' "$ch" >"$CHANNEL_FILE"
  chmod 0644 "$SOURCE" "$CHANNEL_FILE"
}
install_claude() { begin; install_deps; set_repo "${1:-stable}"; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y claude-code; verify_claude; }
repair() { begin; install_deps; set_repo "$(channel)"; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall claude-code; verify_claude; }
reinstall() { begin; install_deps; backup >/dev/null; set_repo "$(channel)"; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall claude-code; verify_claude; }
backup() {
  require_root
  local out="${1:-/root/claude-code-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}" items=()
  [[ "$out" == /* ]] || die "Backup path must be absolute."
  [[ -d /root/.claude ]] && items+=(.claude)
  [[ -f /root/.claude.json ]] && items+=(.claude.json)
  if ((${#items[@]})); then tar -C /root -czf "$out" "${items[@]}"; else tar -czf "$out" --files-from /dev/null; fi
  chmod 0600 "$out"; echo "$out"
}
update() { begin; install_deps; backup >/dev/null; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade claude-code; verify_claude; }
set_channel() { begin; install_deps; set_repo "${1:-}"; apt-get update; info "Claude repository channel set to $(channel). Run update to apply newer packages when available."; }
check_update() { require_root; apt-get update >/dev/null; apt-cache policy claude-code; }
version() { echo "claude-manager $MANAGER_VERSION"; command -v claude >/dev/null && claude --version || true; echo "channel=$(channel)"; }
verify_claude() {
  require_root
  echo '=== Claude Code verification ==='
  command -v claude >/dev/null || die "claude missing."
  claude --version >/dev/null
  [[ -f "$SOURCE" && -f "$KEYRING" ]] || die "APT policy missing."
  local f; f="$(gpg --show-keys --with-colons "$KEYRING" | awk -F: '$1=="fpr"{print $10; exit}')"
  [[ "$f" == "$EXPECTED_FPR" ]] || die "Signing-key fingerprint mismatch."
  grep -Fq "apt/$(channel) $(channel) main" "$SOURCE" || die "APT channel mismatch."
  dpkg -s claude-code >/dev/null 2>&1 || die "claude-code package missing."
  echo 'CLAUDE CODE: VERIFIED'
}
status() { version; dpkg-query -W -f='${Status} ${Version}\n' claude-code 2>/dev/null || true; }
doctor() { status; echo; claude doctor 2>/dev/null || true; echo; cat "$SOURCE" 2>/dev/null || true; echo; apt-cache policy claude-code 2>/dev/null || true; }
help() { cat <<EOF
claude-manager $MANAGER_VERSION
Lifecycle: install [stable|latest] | repair | update | reinstall | check-update | channel stable|latest
Inspection: status | verify | doctor | version
CLI: cli [ARGS...] | mcp [ARGS...] | plugin [ARGS...] | print [ARGS...]
Backup: backup [ABSOLUTE_FILE]
Install source: official Anthropic APT repository with signing fingerprint verification.
EOF
}
case "${1:-help}" in
  install) install_claude "${2:-stable}";; repair) repair;; update) update;; reinstall) reinstall;; check-update) check_update;; channel) set_channel "${2:-}";;
  status) status;; verify) verify_claude;; doctor) doctor;; version) version;;
  cli) shift; exec claude "$@";; mcp) shift; exec claude mcp "$@";; plugin) shift; exec claude plugin "$@";; print) shift; exec claude -p "$@";;
  backup) backup "${2:-}";; help|-h|--help) help;; *) help; exit 2;;
esac
