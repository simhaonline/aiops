#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

# freebuff-manager v1.0.0
# Ubuntu 24.04 LTS
# Freebuff CLI lifecycle through the existing root-scoped nvm-manager.

readonly MANAGER_VERSION="1.0.0"
readonly MANAGER_PATH="/usr/local/bin/freebuff-manager"
readonly LOCK_FILE="/run/lock/freebuff-manager.lock"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
on_error() { local rc=$?; printf '[ERROR] Command failed at line %s (exit %s).\n' "${BASH_LINENO[0]:-?}" "$rc" >&2; exit "$rc"; }
trap on_error ERR
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."; }
require_ubuntu() { [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."; . /etc/os-release; [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || die "Ubuntu 24.04 LTS required."; }
lock() { install -d -m 0755 /run/lock; exec 9>"$LOCK_FILE"; flock -w 120 9 || die "Another freebuff-manager operation is active."; }
self_install() { local s; s="$(readlink -f "${BASH_SOURCE[0]}")"; if [[ "$s" != "$MANAGER_PATH" ]]; then install -o root -g root -m 0755 "$s" "$MANAGER_PATH"; fi; }
begin() { require_root; require_ubuntu; lock; self_install; }

readonly NVM_DIR="/root/.nvm"
readonly NODE_BIN_LINK="${NVM_DIR}/default-bin"
require_nvm() {
  [[ -x /usr/local/bin/nvm-manager ]] || die "nvm-manager is required."
  [[ -s "$NVM_DIR/nvm.sh" ]] || die "NVM runtime missing."
  /usr/local/bin/nvm-manager verify >/dev/null
}
node_cmd() {
  bash --noprofile --norc -c 'set -Eeuo pipefail; export NVM_DIR=/root/.nvm; . "$NVM_DIR/nvm.sh" --no-use; nvm use default >/dev/null; exec "$@"' bash "$@"
}
npm_install() { node_cmd npm install --global "$1"; }

readonly PACKAGE="freebuff"
readonly BIN="${NODE_BIN_LINK}/freebuff"
readonly WRAPPER="/usr/local/bin/freebuff"
install_package() { npm_install "${PACKAGE}@${1:-latest}"; }
write_wrapper() { cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
exec ${BIN} "\$@"
EOF
chmod 0755 "$WRAPPER"; }
install_fb() { begin; require_nvm; install_package latest; write_wrapper; verify_fb; }
repair() { begin; require_nvm; [[ -x "$BIN" ]] || install_package latest; write_wrapper; verify_fb; }
reinstall() { begin; require_nvm; backup >/dev/null; install_package latest; write_wrapper; verify_fb; }
update() { begin; require_nvm; install_package latest; write_wrapper; verify_fb; }
check_update() { require_root; require_nvm; echo "installed=$($BIN --version 2>/dev/null || true)"; echo "latest=$(node_cmd npm view "$PACKAGE" version)"; }
version() { echo "freebuff-manager $MANAGER_VERSION"; [[ -x "$BIN" ]] && "$BIN" --version || true; }
verify_fb() { require_root; echo '=== Freebuff verification ==='; require_nvm; [[ -x "$BIN" ]] || die "Freebuff missing."; [[ -x "$WRAPPER" ]] || die "Canonical wrapper missing."; "$BIN" --help >/dev/null 2>&1 || "$BIN" --version >/dev/null 2>&1 || die "Freebuff smoke test failed."; echo 'FREEBUFF: VERIFIED'; }
status() { version; node_cmd npm list -g --depth=0 "$PACKAGE" 2>/dev/null || true; }
doctor() { status; echo; ls -l "$BIN" "$WRAPPER" 2>/dev/null || true; }
backup() { require_root; local out="${1:-/root/freebuff-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"; [[ "$out" == /* ]] || die "Backup path must be absolute."; local items=(); [[ -d /root/.freebuff ]] && items+=(.freebuff); [[ -d /root/.codebuff ]] && items+=(.codebuff); [[ -d /root/.config/freebuff ]] && items+=(.config/freebuff); [[ -d /root/.config/codebuff ]] && items+=(.config/codebuff); if ((${#items[@]})); then tar -C /root -czf "$out" "${items[@]}"; else tar -czf "$out" --files-from /dev/null; fi; chmod 0600 "$out"; echo "$out"; }
help() { cat <<EOF
freebuff-manager $MANAGER_VERSION
Lifecycle: install | repair | update | reinstall | check-update
Inspection: status | verify | doctor | version
CLI: cli [ARGS...]
Backup: backup [FILE]
Policy: Freebuff is ad-supported. Review its current privacy/data terms before using sensitive repositories.
EOF
}
case "${1:-help}" in
  install) install_fb;; repair) repair;; update) update;; reinstall) reinstall;; check-update) check_update;; status) status;; verify) verify_fb;; doctor) doctor;; version) version;;
  cli) shift; exec "$BIN" "$@";; backup) backup "${2:-}";; help|-h|--help) help;; *) help; exit 2;;
esac
