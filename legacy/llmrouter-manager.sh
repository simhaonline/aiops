#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

# llmrouter-manager v1.0.0
# Ubuntu 24.04 LTS
# LMRouter/lmrouter local API router via @lmrouter/cli and localhost-only systemd service.

readonly MANAGER_VERSION="1.0.0"
readonly MANAGER_PATH="/usr/local/bin/llmrouter-manager"
readonly LOCK_FILE="/run/lock/llmrouter-manager.lock"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
on_error() { local rc=$?; printf '[ERROR] Command failed at line %s (exit %s).\n' "${BASH_LINENO[0]:-?}" "$rc" >&2; exit "$rc"; }
trap on_error ERR
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root."; }
require_ubuntu() { [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."; . /etc/os-release; [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || die "Ubuntu 24.04 LTS required."; }
lock() { install -d -m 0755 /run/lock; exec 9>"$LOCK_FILE"; flock -w 120 9 || die "Another llmrouter-manager operation is active."; }
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

readonly PACKAGE="@lmrouter/cli"
readonly BIN="${NODE_BIN_LINK}/lmrouter"
readonly WRAPPER="/usr/local/bin/lmrouter"
readonly CONF_DIR="/etc/lmrouter"
readonly CONFIG="${CONF_DIR}/config.yaml"
readonly SERVICE="lmrouter.service"
readonly UNIT="/etc/systemd/system/${SERVICE}"
readonly HOST="127.0.0.1"
readonly PORT="3000"

install_deps() { apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl openssl util-linux; }
install_package() { npm_install "${PACKAGE}@${1:-latest}"; }
write_wrapper() { cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
exec ${BIN} "\$@"
EOF
chmod 0755 "$WRAPPER"; }
ensure_config() {
  install -d -o root -g root -m 0755 "$CONF_DIR"
  if [[ ! -f "$CONFIG" ]]; then
    local key; key="sk-$(openssl rand -hex 32)"
    cat >"$CONFIG" <<EOF
server:
  host: 127.0.0.1
  port: 3000
  logging: dev

auth:
  enabled: false

responses_store:
  type: in_memory

access_keys:
  - ${key}

# Configure at least one provider/model before production use.
providers: {}
models: {}
EOF
  fi
  chown root:root "$CONFIG"; chmod 0600 "$CONFIG"
}
write_unit() { cat >"$UNIT" <<EOF
[Unit]
Description=LMRouter API Router (localhost only)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=HOME=/root
WorkingDirectory=${CONF_DIR}
ExecStart=${BIN} ${CONFIG}
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
LockPersonality=true
RestrictRealtime=true

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$UNIT"; systemctl daemon-reload; }
install_lmr() { begin; install_deps; require_nvm; install_package latest; write_wrapper; ensure_config; write_unit; verify_lmr; }
repair() { begin; install_deps; require_nvm; [[ -x "$BIN" ]] || install_package latest; write_wrapper; ensure_config; write_unit; verify_lmr; }
reinstall() { begin; install_deps; require_nvm; backup >/dev/null; install_package latest; write_wrapper; ensure_config; write_unit; if systemctl is-active --quiet "$SERVICE"; then systemctl restart "$SERVICE"; fi; verify_lmr; }
update() { begin; require_nvm; backup >/dev/null; install_package latest; write_wrapper; if systemctl is-active --quiet "$SERVICE"; then systemctl restart "$SERVICE"; fi; verify_lmr; }
check_update() { require_root; require_nvm; echo "installed:"; node_cmd npm list -g --depth=0 "$PACKAGE" 2>/dev/null | tail -2 || true; echo "latest=$(node_cmd npm view "$PACKAGE" version)"; }
version() { echo "llmrouter-manager $MANAGER_VERSION"; if [[ -x "$BIN" ]]; then node_cmd npm list -g --depth=0 "$PACKAGE" 2>/dev/null | tail -2 || true; fi; }
loopcheck() { local bad; bad="$(ss -H -lnt 2>/dev/null | awk '$4 ~ /:3000$/ {print $4}' | grep -Ev '^(127\.0\.0\.1:3000|\[::1\]:3000)$' || true)"; [[ -z "$bad" ]] || die "Unsafe LMRouter listener: $bad"; }
listener_present() { ss -H -lnt 2>/dev/null | awk '{print $4}' | grep -Eq '^(127\.0\.0\.1:3000|\[::1\]:3000)$'; }
wait_listener() { local i; for i in $(seq 1 30); do loopcheck; listener_present && return 0; sleep 1; done; return 1; }
config_check() { require_root; grep -Eq '^server:' "$CONFIG" || die "Missing server config."; grep -Eq '^[[:space:]]+host:[[:space:]]+127\.0\.0\.1[[:space:]]*$' "$CONFIG" || die "LMRouter must bind 127.0.0.1."; grep -Eq '^[[:space:]]+port:[[:space:]]+3000[[:space:]]*$' "$CONFIG" || die "LMRouter port must be 3000."; grep -Eq '^access_keys:' "$CONFIG" || die "access_keys missing."; echo 'config: OK'; }
verify_lmr() { require_root; echo '=== LMRouter verification ==='; require_nvm; [[ -x "$BIN" && -x "$WRAPPER" && -f "$CONFIG" && -f "$UNIT" ]] || die "Managed runtime/config missing."; [[ "$(stat -c %a "$CONFIG")" == 600 ]] || die "LMRouter config must be 0600 because it contains access/provider keys."; config_check >/dev/null; loopcheck; if systemctl is-enabled --quiet "$SERVICE" 2>/dev/null; then systemctl is-active --quiet "$SERVICE" || die "LMRouter is enabled but inactive."; listener_present || die "LMRouter is active but not listening on 127.0.0.1:3000."; fi; echo 'LMROUTER: VERIFIED'; }
start() { require_root; config_check >/dev/null; systemctl enable --now "$SERVICE"; systemctl is-active --quiet "$SERVICE" || { journalctl -u "$SERVICE" -n 100 --no-pager >&2; die "LMRouter failed. Configure providers/models in $CONFIG first."; }; wait_listener || { journalctl -u "$SERVICE" -n 100 --no-pager >&2; die "LMRouter did not open 127.0.0.1:3000."; }; }
stop() { require_root; systemctl stop "$SERVICE"; }
restart() { require_root; config_check >/dev/null; systemctl restart "$SERVICE"; systemctl is-active --quiet "$SERVICE" || die "LMRouter failed."; wait_listener || { journalctl -u "$SERVICE" -n 100 --no-pager >&2; die "LMRouter did not open 127.0.0.1:3000."; }; }
status() { version; echo "Config: $CONFIG"; echo "Router: http://127.0.0.1:3000"; systemctl --no-pager --full status "$SERVICE" 2>/dev/null | sed -n '1,24p' || true; }
logs() { require_root; journalctl -u "$SERVICE" -n "${1:-200}" --no-pager; }
doctor() { status; echo; config_check 2>/dev/null || true; echo; ss -H -lntp | grep ':3000' || true; echo; logs 80 || true; }
backup() { require_root; local out="${1:-/root/lmrouter-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"; [[ "$out" == /* ]] || die "Backup path must be absolute."; tar -C / -czf "$out" etc/lmrouter 2>/dev/null || tar -czf "$out" --files-from /dev/null; chmod 0600 "$out"; echo "$out"; }
nginx_setup() { require_root; local domain="${1:-}" email="${2:-}"; [[ -n "$domain" && -n "$email" ]] || die "Usage: llmrouter-manager nginx-setup DOMAIN EMAIL"; [[ -x /usr/local/bin/nginx-manager ]] || die "nginx-manager is required."; /usr/local/bin/nginx-manager proxy-add-api "$domain" "http://127.0.0.1:3000"; /usr/local/bin/nginx-manager ssl-issue "$domain" "$email"; /usr/local/bin/nginx-manager site-verify "$domain"; }
help() { cat <<EOF
llmrouter-manager $MANAGER_VERSION
Target: LMRouter/lmrouter package @lmrouter/cli
Lifecycle: install | repair | update | reinstall | check-update
Service: start | stop | restart | status | logs [N]
Inspection: verify | doctor | version | config-check
Public edge: nginx-setup DOMAIN EMAIL
Backup: backup [FILE]
Config: ${CONFIG} (0600); server fixed to http://127.0.0.1:3000. Configure providers/models before starting.
EOF
}
case "${1:-help}" in
  install) install_lmr;; repair) repair;; update) update;; reinstall) reinstall;; check-update) check_update;; start) start;; stop) stop;; restart) restart;; status) status;; logs) logs "${2:-200}";;
  verify) verify_lmr;; doctor) doctor;; version) version;; config-check) config_check;; nginx-setup) nginx_setup "${2:-}" "${3:-}";; backup) backup "${2:-}";;
  help|-h|--help) help;; *) help; exit 2;;
esac
