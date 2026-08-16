#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/system-manager}"
[[ -f "$SCRIPT" ]] || { echo "missing: $SCRIPT" >&2; exit 1; }

extract_func(){
  local name="$1"
  awk -v n="$name" '
    $0 ~ "^" n "\\(\\)[[:space:]]*\\{" {p=1}
    p {print}
    p && /^}/ {exit}
  ' "$SCRIPT"
}

apt_body="$(extract_func apt_install)"
repair_body="$(extract_func repair)"

[[ "$apt_body" != *"full-upgrade"* ]]
[[ "$apt_body" != *"upgrade -y"* ]]
! grep -Fq 'Acquire::ForceIPv4' "$SCRIPT"
grep -Fq 'readonly SSH_DROPIN="/etc/ssh/sshd_config.d/00-simha-system-manager.conf"' "$SCRIPT"
grep -Fq 'root_login="prohibit-password"' "$SCRIPT"
grep -Fq 'AllowTcpForwarding yes' "$SCRIPT"
grep -Fq 'GatewayPorts no' "$SCRIPT"
[[ "$repair_body" != *"read -r -s -p"* ]]
[[ "$repair_body" != *"chpasswd"* ]]
! grep -Fq 'Etc/GMT-3' "$SCRIPT"
! grep -Fq '99-kubernetes-limits.conf' "$SCRIPT"
! grep -Fq 'soft nproc 512000' "$SCRIPT"
! grep -Eq '> *(/etc/netplan/|"/etc/netplan/)' "$SCRIPT"
grep -Fq 'full-upgrade -y' "$SCRIPT"
grep -Fq 'Automatic-Reboot "false"' "$SCRIPT"
grep -Fq 'No automatic reboot' "$SCRIPT"

bash -n "$SCRIPT"
"$SCRIPT" help >/dev/null
"$SCRIPT" version | grep -Fq 'system-manager 1.0.0'

# Exact regression for the default sysadmin account:
# the manager owns a sysadmin group, so a new sysadmin user must reuse that
# group with --gid instead of attempting --user-group.
(
  # shellcheck disable=SC1090
  source "$SCRIPT"
  trap - ERR

  MOCK_USER_EXISTS=0
  MOCK_PRIMARY_GROUP=""
  MOCK_TARGET_USER=""
  LAST_USERADD=""
  LAST_USERMOD=""

  getent(){
    case "${1:-}:${2:-}" in
      group:sudo|group:sysadmin) return 0 ;;
      group:opsadmin) return 2 ;;
      passwd:*) return 2 ;;
      *) return 2 ;;
    esac
  }

  groupadd(){
    echo "unexpected groupadd: $*" >&2
    return 90
  }

  id(){
    case "${1:-}" in
      -u)
        [[ "$MOCK_USER_EXISTS" == 1 && "${2:-}" == "$MOCK_TARGET_USER" ]] || return 1
        printf '1001\n'
        ;;
      -gn)
        [[ "$MOCK_USER_EXISTS" == 1 && "${2:-}" == "$MOCK_TARGET_USER" ]] || return 1
        printf '%s\n' "$MOCK_PRIMARY_GROUP"
        ;;
      *)
        [[ "$MOCK_USER_EXISTS" == 1 && "${1:-}" == "$MOCK_TARGET_USER" ]] || return 1
        printf 'uid=1001(%s) gid=1001(%s)\n' "$MOCK_TARGET_USER" "$MOCK_PRIMARY_GROUP"
        ;;
    esac
  }

  useradd(){
    local arg next_primary="" create_private=0
    local args=("$@")
    LAST_USERADD="$(printf '%q ' "$@")"
    for ((i=0; i<${#args[@]}; i++)); do
      arg="${args[$i]}"
      case "$arg" in
        --gid|-g)
          ((i+=1))
          next_primary="${args[$i]}"
          ;;
        --user-group|-U)
          create_private=1
          ;;
      esac
    done
    MOCK_TARGET_USER="${args[-1]}"
    MOCK_USER_EXISTS=1
    if [[ "$create_private" == 1 ]]; then
      MOCK_PRIMARY_GROUP="$MOCK_TARGET_USER"
    else
      MOCK_PRIMARY_GROUP="$next_primary"
    fi
    [[ -n "$MOCK_PRIMARY_GROUP" ]]
  }

  usermod(){
    LAST_USERMOD="$(printf '%q ' "$@")"
    return 0
  }

  primary=""

  # Default path that previously failed:
  MOCK_USER_EXISTS=0
  MOCK_TARGET_USER="sysadmin"
  ensure_admin_account "sysadmin" primary
  [[ "$primary" == "sysadmin" ]]
  [[ "$LAST_USERADD" == *"--gid sysadmin"* ]]
  [[ "$LAST_USERADD" != *"--user-group"* ]]
  [[ "$LAST_USERADD" == *"--groups sudo"* ]]

  # Normal private-group path for a custom administrator:
  MOCK_USER_EXISTS=0
  MOCK_TARGET_USER="opsadmin"
  MOCK_PRIMARY_GROUP=""
  LAST_USERADD=""
  ensure_admin_account "opsadmin" primary
  [[ "$primary" == "opsadmin" ]]
  [[ "$LAST_USERADD" == *"--user-group"* ]]
  [[ "$LAST_USERADD" == *"--groups sudo\\,sysadmin"* || "$LAST_USERADD" == *"--groups sudo,sysadmin"* ]]

  # Existing account path must never call useradd.
  MOCK_USER_EXISTS=1
  MOCK_TARGET_USER="sysadmin"
  MOCK_PRIMARY_GROUP="sysadmin"
  LAST_USERADD=""
  LAST_USERMOD=""
  ensure_admin_account "sysadmin" primary
  [[ "$primary" == "sysadmin" ]]
  [[ -z "$LAST_USERADD" ]]
  [[ "$LAST_USERMOD" == *"-aG sudo"* ]]
)

echo 'SYSTEM-MANAGER USER/GROUP COLLISION REGRESSION: PASS'

# Regression for the exact exit-141 class:
# current_ssh_port must consume the complete sshd stream under pipefail instead
# of making sshd die from SIGPIPE after the first "port" line.
(
  # shellcheck disable=SC1090
  source "$SCRIPT"
  trap - ERR

  sshd(){
    printf 'port 22\n'
    local i
    for ((i=0; i<20000; i++)); do
      printf 'dummyoption%d value\n' "$i"
    done
  }

  [[ "$(current_ssh_port)" == "22" ]]
)

grep -Fq 'allowipv6 = auto' "$SCRIPT"
grep -Fq 'FAIL2BAN_GLOBAL_LOCAL="/etc/fail2ban/fail2ban.local"' "$SCRIPT"

echo 'SYSTEM-MANAGER PIPEFAIL/SIGPIPE REGRESSION: PASS'
echo 'SYSTEM-MANAGER FAIL2BAN GLOBAL POLICY REGRESSION: PASS'
echo 'SYSTEM-MANAGER REGRESSION: PASS'
