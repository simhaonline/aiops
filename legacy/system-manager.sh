#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

# =============================================================================
# system-manager
# Version: 1.0.0
# Target: Ubuntu Server 24.04 LTS
#
# Purpose:
#   Establish a safe, repeatable base OS for the SIMHA Manager Suite without
#   taking ownership of provider-specific networking/netplan or application
#   ports. Runtime managers remain responsible for their own application setup.
#
# Design rules:
#   - Ubuntu 24.04 only.
#   - No repeated full-upgrades during package installation.
#   - No forced IPv4 APT policy.
#   - Preserve netplan/provider networking.
#   - Default SSH policy: root key-only, admin password/key login allowed.
#   - UFW opens the effective SSH port before enabling the firewall.
#   - Repair is idempotent and never resets passwords.
#   - Back up every managed existing config before replacement.
#   - No automatic reboot.
# =============================================================================

readonly SYSTEM_MANAGER_VERSION="1.0.0"
readonly MANAGER_PATH="/usr/local/bin/system-manager"
readonly STATE_DIR="/var/lib/simha-system-manager"
readonly BACKUP_ROOT="/var/backups/simha-system-manager"
readonly LOG_FILE="/var/log/simha-system-manager.log"
readonly LOCK_FILE="/run/lock/simha-system-manager.lock"
readonly CONFIG_FILE="${STATE_DIR}/config"

readonly APT_POLICY_FILE="/etc/apt/apt.conf.d/99-simha-system-manager"
readonly UNATTENDED_FILE="/etc/apt/apt.conf.d/52-simha-unattended-upgrades"
readonly SSH_DROPIN="/etc/ssh/sshd_config.d/00-simha-system-manager.conf"
readonly FAIL2BAN_FILE="/etc/fail2ban/jail.d/99-simha-sshd.local"
readonly FAIL2BAN_GLOBAL_LOCAL="/etc/fail2ban/fail2ban.local"
readonly LIMITS_FILE="/etc/security/limits.d/99-simha-limits.conf"
readonly SYSTEMD_LIMITS_FILE="/etc/systemd/system.conf.d/99-simha-limits.conf"
readonly SHELL_PROFILE="/etc/profile.d/99-simha-admin-bash.sh"
readonly ISSUE_FILE="/etc/issue"

readonly DEFAULT_ADMIN_USER="sysadmin"
readonly DEFAULT_SSH_MODE="secure"
readonly DEFAULT_TIMEZONE="Etc/UTC"

APT_UPDATED=0

say(){ printf '%-24s %s\n' "$1" "$2"; }
info(){ printf '[INFO] %s\n' "$*"; }
warn(){ printf '[WARN] %s\n' "$*" >&2; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

on_error(){
  local line="$1" rc="$2" cmd="$3"
  printf '[ERROR] Command failed at line %s (exit %s): %s\n' "$line" "$rc" "$cmd" >&2
  printf '[ERROR] See %s\n' "$LOG_FILE" >&2
}
trap 'on_error "$LINENO" "$?" "$BASH_COMMAND"' ERR

require_root(){ [[ ${EUID:-999} -eq 0 ]] || die "Run as root: sudo $0 ${*:-}"; }

require_ubuntu_2404(){
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || die "Ubuntu is required; detected ${ID:-unknown}."
  [[ "${VERSION_ID:-}" == "24.04" ]] || die "Ubuntu 24.04 LTS is required; detected ${VERSION_ID:-unknown}."
}

acquire_lock(){
  install -d -m 0755 /run/lock
  exec 9>"$LOCK_FILE"
  flock -w 120 9 || die "Another system-manager operation is active."
}

setup_logging(){
  install -d -o root -g root -m 0700 "$STATE_DIR" "$BACKUP_ROOT"
  touch "$LOG_FILE"
  chown root:root "$LOG_FILE"
  chmod 0600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

self_install(){
  local src
  src="$(readlink -f "${BASH_SOURCE[0]}")"
  if [[ "$src" != "$MANAGER_PATH" ]]; then
    install -o root -g root -m 0755 "$src" "$MANAGER_PATH"
    info "Installed manager -> $MANAGER_PATH"
  else
    chown root:root "$MANAGER_PATH"
    chmod 0755 "$MANAGER_PATH"
  fi
}

begin_mutation(){
  require_root "$*"
  require_ubuntu_2404
  acquire_lock
  setup_logging
  self_install
}

backup_file(){
  local src="$1"
  [[ -e "$src" || -L "$src" ]] || return 0

  local stamp safe dest
  stamp="$(date -u +%Y%m%dT%H%M%S.%NZ)"
  safe="${src#/}"
  safe="${safe//\//__}"
  dest="${BACKUP_ROOT}/${stamp}__${safe}"
  cp -a -- "$src" "$dest"
  info "Backup: $dest"
  return 0
}

apt_update_once(){
  if (( APT_UPDATED == 0 )); then
    DEBIAN_FRONTEND=noninteractive apt-get \
      -o DPkg::Lock::Timeout=600 \
      -o Acquire::Retries=5 \
      update
    APT_UPDATED=1
  fi
}

apt_install(){
  (( $# > 0 )) || return 0
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=600 \
    -o Acquire::Retries=5 \
    install -y --no-install-recommends "$@"
}

apt_upgrade_safe(){
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=600 \
    -o Acquire::Retries=5 \
    upgrade -y
}

configure_apt(){
  backup_file "$APT_POLICY_FILE"
  cat > "$APT_POLICY_FILE" <<'EOF_APT'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "5";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::Languages "none";
Dpkg::Use-Pty "0";
EOF_APT
  chown root:root "$APT_POLICY_FILE"
  chmod 0644 "$APT_POLICY_FILE"
}

install_base_packages(){
  local packages=(
    acl
    apparmor-utils
    auditd
    autoconf
    automake
    audispd-plugins
    bash-completion
    bc
    bzip2
    bubblewrap
    build-essential
    ca-certificates
    chrony
    cmake
    cron
    curl
    dkms
    dnsutils
    fd-find
    ffmpeg
    file
    git
    gnupg
    gzip
    htop
    iftop
    iotop-c
    iproute2
    jq
    less
    libffi-dev
    libssl-dev
    libtool
    lsof
    make
    mtr-tiny
    nano
    net-tools
    needrestart
    openssh-client
    openssh-server
    openssl
    parallel
    pkg-config
    plocate
    python3
    python3-dev
    python3-pip
    python3-venv
    ripgrep
    rsync
    screen
    strace
    socat
    sudo
    sysstat
    tar
    tcpdump
    tmux
    traceroute
    tree
    ufw
    unattended-upgrades
    unzip
    util-linux
    vnstat
    wget
    xz-utils
    zip
  )

  apt_install "${packages[@]}"
}

prompt_secret(){
  local label="$1" var_name="$2" first second
  while :; do
    read -r -s -p "$label: " first; printf '\n'
    [[ -n "$first" ]] || { warn "Password cannot be empty."; continue; }
    read -r -s -p "Confirm $label: " second; printf '\n'
    if [[ "$first" == "$second" ]]; then
      printf -v "$var_name" '%s' "$first"
      return 0
    fi
    warn "Passwords do not match."
  done
}

validate_hostname(){
  local value="$1"
  [[ ${#value} -le 253 ]] || return 1
  [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || return 1
  [[ "$value" != *".."* ]] || return 1
}

validate_username(){
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

validate_timezone(){
  local tz="$1"
  timedatectl list-timezones 2>/dev/null | grep -Fxq "$tz"
}

prompt_identity(){
  local current_host current_tz answer
  current_host="$(hostname -f 2>/dev/null || hostname)"
  current_tz="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  current_tz="${current_tz:-$DEFAULT_TIMEZONE}"

  read -r -p "Hostname/FQDN [$current_host]: " HOSTNAME_VALUE
  HOSTNAME_VALUE="${HOSTNAME_VALUE:-$current_host}"
  validate_hostname "$HOSTNAME_VALUE" || die "Invalid hostname/FQDN: $HOSTNAME_VALUE"

  read -r -p "Administrative username [$DEFAULT_ADMIN_USER]: " ADMIN_USER
  ADMIN_USER="${ADMIN_USER:-$DEFAULT_ADMIN_USER}"
  validate_username "$ADMIN_USER" || die "Invalid Linux username: $ADMIN_USER"
  [[ "$ADMIN_USER" != "root" ]] || die "Administrative username must not be root."

  read -r -p "Timezone [$current_tz]: " TIMEZONE_VALUE
  TIMEZONE_VALUE="${TIMEZONE_VALUE:-$current_tz}"
  validate_timezone "$TIMEZONE_VALUE" || die "Unknown timezone: $TIMEZONE_VALUE"

  printf '\nSSH modes:\n'
  printf '  secure    root via SSH key only; admin password/key allowed (recommended)\n'
  printf '  keys-only root/admin SSH keys only; password authentication disabled\n'
  printf '  compat    root/admin password or key allowed (least secure)\n'
  read -r -p "SSH mode [$DEFAULT_SSH_MODE]: " SSH_MODE
  SSH_MODE="${SSH_MODE:-$DEFAULT_SSH_MODE}"
  case "$SSH_MODE" in secure|keys-only|compat) ;; *) die "Invalid SSH mode: $SSH_MODE" ;; esac

  if id "$ADMIN_USER" >/dev/null 2>&1; then
    read -r -p "Reset password for existing ${ADMIN_USER}? [y/N]: " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      prompt_secret "${ADMIN_USER} password" ADMIN_PASSWORD
      RESET_ADMIN_PASSWORD=1
    else
      ADMIN_PASSWORD=""
      RESET_ADMIN_PASSWORD=0
    fi
  else
    prompt_secret "${ADMIN_USER} password" ADMIN_PASSWORD
    RESET_ADMIN_PASSWORD=1
  fi

  read -r -p "Set/reset local root password? [y/N]: " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    prompt_secret "Root password" ROOT_PASSWORD
    RESET_ROOT_PASSWORD=1
  else
    ROOT_PASSWORD=""
    RESET_ROOT_PASSWORD=0
  fi

  read -r -p "Apply available package upgrades during initial install? [Y/n]: " answer
  if [[ "$answer" =~ ^[Nn]$ ]]; then
    APPLY_INITIAL_UPDATES=0
  else
    APPLY_INITIAL_UPDATES=1
  fi
}

admin_supplementary_groups(){
  local primary_group="$1" output_var="$2"
  local groups=()

  [[ "$primary_group" == "sudo" ]] || groups+=(sudo)
  [[ "$primary_group" == "sysadmin" ]] || groups+=(sysadmin)

  local joined=""
  if ((${#groups[@]})); then
    local old_ifs="$IFS"
    IFS=,
    joined="${groups[*]}"
    IFS="$old_ifs"
  fi
  printf -v "$output_var" '%s' "$joined"
}

ensure_admin_account(){
  local user="$1" output_var="$2"
  local resolved_primary="" supplementary=""
  local args=()

  getent group sudo >/dev/null 2>&1 || die "Required 'sudo' group is missing."
  getent group sysadmin >/dev/null 2>&1 || groupadd --system sysadmin

  if id -u "$user" >/dev/null 2>&1; then
    usermod -s /bin/bash "$user"
    resolved_primary="$(id -gn "$user")"
    admin_supplementary_groups "$resolved_primary" supplementary
    [[ -z "$supplementary" ]] || usermod -aG "$supplementary" "$user"
  else
    args=(--create-home --shell /bin/bash)

    if getent group "$user" >/dev/null 2>&1; then
      resolved_primary="$user"
      args+=(--gid "$resolved_primary")
    else
      resolved_primary="$user"
      args+=(--user-group)
    fi

    admin_supplementary_groups "$resolved_primary" supplementary
    [[ -z "$supplementary" ]] || args+=(--groups "$supplementary")
    useradd "${args[@]}" "$user"

    id -u "$user" >/dev/null 2>&1 || die "Administrative user creation did not produce account '$user'."
    resolved_primary="$(id -gn "$user")"
  fi

  printf -v "$output_var" '%s' "$resolved_primary"
}

configure_admin_user(){
  local user="$1" password="${2:-}" reset_password="${3:-0}" primary_group=""

  ensure_admin_account "$user" primary_group
  [[ -n "$primary_group" ]] || die "Could not resolve primary group for '$user'."

  if [[ "$reset_password" == "1" ]]; then
    [[ -n "$password" ]] || die "Administrative password is empty."
    printf '%s:%s\n' "$user" "$password" | chpasswd
  fi

  install -d -m 0700 -o "$user" -g "$primary_group" "/home/$user/.ssh"

  local sudo_file="/etc/sudoers.d/90-simha-${user}"
  backup_file "$sudo_file"
  printf '%s ALL=(ALL:ALL) ALL\n' "$user" > "$sudo_file"
  chown root:root "$sudo_file"
  chmod 0440 "$sudo_file"
  visudo -cf "$sudo_file" >/dev/null
}

configure_root_password(){
  local password="$1" reset_password="$2"
  [[ "$reset_password" == "1" ]] || return 0
  [[ -n "$password" ]] || die "Root password is empty."
  printf 'root:%s\n' "$password" | chpasswd
}

configure_hostname(){
  local fqdn="$1" short tmp
  short="${fqdn%%.*}"

  backup_file /etc/hostname
  backup_file /etc/hosts
  backup_file /etc/machine-info

  hostnamectl set-hostname "$fqdn"
  printf '%s\n' "$fqdn" > /etc/hostname
  printf 'PRETTY_HOSTNAME=%s\nICON_NAME=computer-server\nCHASSIS=server\n' "$fqdn" > /etc/machine-info

  tmp="$(mktemp /etc/hosts.simha.XXXXXX)"
  awk '$1 != "127.0.1.1" { print }' /etc/hosts > "$tmp"
  if [[ "$fqdn" == "$short" ]]; then
    printf '127.0.1.1 %s\n' "$short" >> "$tmp"
  else
    printf '127.0.1.1 %s %s\n' "$fqdn" "$short" >> "$tmp"
  fi
  chown root:root "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" /etc/hosts

  systemctl restart systemd-hostnamed 2>/dev/null || true
}

configure_time(){
  local timezone="$1"
  apt_install chrony
  timedatectl set-timezone "$timezone"
  systemctl enable --now chrony
  chronyc tracking >/dev/null 2>&1 || warn "chronyc tracking is not ready yet; it may need a short synchronization period."
}

current_ssh_port(){
  local port=""
  # Do not exit awk early here. With `set -o pipefail`, an early consumer can
  # close the pipe while sshd is still writing, making sshd receive SIGPIPE
  # (exit 141) and turning a successful lookup into a fatal pipeline failure.
  port="$(
    sshd -T 2>/dev/null |
      awk '$1=="port" && !seen {port=$2; seen=1} END {if (seen) print port}'
  )"
  printf '%s\n' "${port:-22}"
}

write_ssh_policy(){
  local mode="$1"
  backup_file "$SSH_DROPIN"
  install -d -o root -g root -m 0755 /etc/ssh/sshd_config.d

  local root_login password_auth
  case "$mode" in
    secure)
      root_login="prohibit-password"
      password_auth="yes"
      ;;
    keys-only)
      root_login="prohibit-password"
      password_auth="no"
      ;;
    compat)
      root_login="yes"
      password_auth="yes"
      ;;
    *) die "Invalid SSH mode: $mode" ;;
  esac

  cat > "$SSH_DROPIN" <<EOF_SSH
# Managed by system-manager. Filename begins with 00 because OpenSSH uses the first obtained value.
PermitRootLogin ${root_login}
PasswordAuthentication ${password_auth}
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding yes
GatewayPorts no
PermitTunnel no
ClientAliveInterval 300
ClientAliveCountMax 3
UseDNS no
Banner ${ISSUE_FILE}
EOF_SSH
  chown root:root "$SSH_DROPIN"
  chmod 0644 "$SSH_DROPIN"
  sshd -t
}

ufw_is_active(){
  local status=""
  status="$(ufw status 2>/dev/null)" || return 1
  [[ "${status%%$'\n'*}" == "Status: active" ]]
}

state_value(){
  local key="$1"
  awk -F= -v key="$key" '
    $1==key && !seen {
      sub(/^[^=]*=/, "")
      print
      seen=1
    }
  ' "$CONFIG_FILE"
}

ensure_fail2ban_global_policy(){
  backup_file "$FAIL2BAN_GLOBAL_LOCAL"

  local tmp
  tmp="$(mktemp /etc/fail2ban/.simha-fail2ban.local.XXXXXX)"
  if [[ -f "$FAIL2BAN_GLOBAL_LOCAL" ]]; then
    awk '
      BEGIN {
        in_default=0
        saw_default=0
        wrote_allowipv6=0
      }

      /^[[:space:]]*\[DEFAULT\][[:space:]]*$/ {
        if (in_default && !wrote_allowipv6) {
          print "allowipv6 = auto"
          wrote_allowipv6=1
        }
        in_default=1
        saw_default=1
        print
        next
      }

      /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        if (in_default && !wrote_allowipv6) {
          print "allowipv6 = auto"
          wrote_allowipv6=1
        }
        in_default=0
        print
        next
      }

      {
        if (in_default &&
            $0 ~ /^[[:space:]]*allowipv6[[:space:]]*=/) {
          if (!wrote_allowipv6) {
            print "allowipv6 = auto"
            wrote_allowipv6=1
          }
          next
        }
        print
      }

      END {
        if (in_default && !wrote_allowipv6) {
          print "allowipv6 = auto"
          wrote_allowipv6=1
        }
        if (!saw_default) {
          print ""
          print "[DEFAULT]"
          print "allowipv6 = auto"
        }
      }
    ' "$FAIL2BAN_GLOBAL_LOCAL" >"$tmp"
  else
    cat >"$tmp" <<'EOF_F2B_GLOBAL'
[DEFAULT]
allowipv6 = auto
EOF_F2B_GLOBAL
  fi

  chown root:root "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$FAIL2BAN_GLOBAL_LOCAL"
}

configure_firewall(){
  local ssh_port="$1"
  command -v ufw >/dev/null 2>&1 || die "ufw is not installed."

  ufw allow "${ssh_port}/tcp" comment 'SIMHA SSH' >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null

  if ! ufw_is_active; then
    ufw --force enable >/dev/null
  fi
}

configure_fail2ban(){
  ensure_fail2ban_global_policy
  backup_file "$FAIL2BAN_FILE"
  cat > "$FAIL2BAN_FILE" <<'EOF_F2B'
[sshd]
enabled = true
backend = systemd
filter = sshd
maxretry = 5
findtime = 10m
bantime = 12h
banaction = ufw
ignoreip = 127.0.0.1/8 ::1
EOF_F2B
  chown root:root "$FAIL2BAN_FILE"
  chmod 0644 "$FAIL2BAN_FILE"
  fail2ban-client -t >/dev/null
  systemctl enable --now fail2ban
  systemctl restart fail2ban
}

configure_banner(){
  backup_file "$ISSUE_FILE"
  cat > "$ISSUE_FILE" <<'EOF_ISSUE'
####################################################################################################
# Authorized access only. Connections may be monitored and logged for security and administration. #
####################################################################################################
EOF_ISSUE
  chown root:root "$ISSUE_FILE"
  chmod 0644 "$ISSUE_FILE"
}

configure_security(){
  local ssh_mode="$1"
  apt_install ufw fail2ban openssh-server openssh-client
  configure_banner
  write_ssh_policy "$ssh_mode"

  local ssh_port
  ssh_port="$(current_ssh_port)"
  configure_firewall "$ssh_port"
  configure_fail2ban

  systemctl enable --now ssh
  systemctl reload ssh
}

configure_limits(){
  backup_file "$LIMITS_FILE"
  backup_file "$SYSTEMD_LIMITS_FILE"
  install -d -o root -g root -m 0755 /etc/systemd/system.conf.d

  cat > "$LIMITS_FILE" <<'EOF_LIMITS'
# Managed by system-manager. Application managers may impose stricter limits.
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF_LIMITS

  cat > "$SYSTEMD_LIMITS_FILE" <<'EOF_SYSTEMD'
[Manager]
DefaultLimitNOFILE=1048576:1048576
EOF_SYSTEMD

  chown root:root "$LIMITS_FILE" "$SYSTEMD_LIMITS_FILE"
  chmod 0644 "$LIMITS_FILE" "$SYSTEMD_LIMITS_FILE"
  systemctl daemon-reexec
}

configure_shell(){
  backup_file "$SHELL_PROFILE"
  cat > "$SHELL_PROFILE" <<'EOF_SHELL'
# Managed by system-manager.
[[ $- != *i* ]] && return
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias ports='ss -tulpn'
alias meminfo='free -h'
export HISTSIZE=200000
export HISTFILESIZE=500000
export HISTTIMEFORMAT='%F %T '
export HISTCONTROL=ignoredups:erasedups
export LANG=C.UTF-8
shopt -s histappend
[[ "${PROMPT_COMMAND:-}" != *"history -a"* ]] && PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"
case ":$PATH:" in *:/usr/local/sbin:*) ;; *) export PATH="/usr/local/sbin:/usr/local/bin:$PATH" ;; esac
if [[ "$(id -u)" -eq 0 ]]; then
  PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
else
  PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
fi
[[ -r /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion
EOF_SHELL
  chown root:root "$SHELL_PROFILE"
  chmod 0644 "$SHELL_PROFILE"
}

configure_auto_updates(){
  apt_install unattended-upgrades
  backup_file /etc/apt/apt.conf.d/20auto-upgrades
  backup_file "$UNATTENDED_FILE"

  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF_AUTO'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF_AUTO

  cat > "$UNATTENDED_FILE" <<'EOF_UU'
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF_UU

  chown root:root /etc/apt/apt.conf.d/20auto-upgrades "$UNATTENDED_FILE"
  chmod 0644 /etc/apt/apt.conf.d/20auto-upgrades "$UNATTENDED_FILE"
}

configure_observability(){
  if [[ -f /etc/default/sysstat ]]; then
    backup_file /etc/default/sysstat
    if grep -q '^ENABLED=' /etc/default/sysstat; then
      sed -i 's/^ENABLED=.*/ENABLED="true"/' /etc/default/sysstat
    else
      printf '\nENABLED="true"\n' >> /etc/default/sysstat
    fi
  fi
  systemctl enable --now sysstat 2>/dev/null || true
  systemctl enable --now vnstat 2>/dev/null || true
  systemctl enable --now auditd 2>/dev/null || true
}

write_state(){
  local hostname_value="$1" admin_user="$2" timezone="$3" ssh_mode="$4"
  cat > "$CONFIG_FILE" <<EOF_STATE
HOSTNAME=${hostname_value}
ADMIN_USER=${admin_user}
TIMEZONE=${timezone}
SSH_MODE=${ssh_mode}
EOF_STATE
  printf '%s\n' "$SYSTEM_MANAGER_VERSION" > "${STATE_DIR}/version"
  chown root:root "$CONFIG_FILE" "${STATE_DIR}/version"
  chmod 0600 "$CONFIG_FILE" "${STATE_DIR}/version"
}

load_state(){
  [[ -r "$CONFIG_FILE" ]] || die "State file is missing: $CONFIG_FILE. Run install/configure first."

  HOSTNAME_VALUE="$(state_value HOSTNAME)"
  ADMIN_USER="$(state_value ADMIN_USER)"
  TIMEZONE_VALUE="$(state_value TIMEZONE)"
  SSH_MODE="$(state_value SSH_MODE)"

  validate_hostname "$HOSTNAME_VALUE" || die "Invalid stored HOSTNAME."
  validate_username "$ADMIN_USER" || die "Invalid stored ADMIN_USER."
  validate_timezone "$TIMEZONE_VALUE" || die "Invalid stored TIMEZONE."
  case "$SSH_MODE" in secure|keys-only|compat) ;; *) die "Invalid stored SSH_MODE." ;; esac
}

preflight(){
  require_ubuntu_2404
  command -v systemctl >/dev/null 2>&1 || die "systemd/systemctl is required."
  [[ -d /run/systemd/system ]] || die "systemd is not running as PID 1."

  local free_kb
  free_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  [[ "$free_kb" =~ ^[0-9]+$ ]] || die "Unable to determine free disk space."
  (( free_kb >= 2097152 )) || die "At least 2 GiB free space on / is required."

  if command -v dpkg >/dev/null 2>&1; then
    local audit
    audit="$(dpkg --audit 2>&1 || true)"
    [[ -z "$audit" ]] || warn "dpkg --audit reported issues; package repair may be required:\n$audit"
  fi
}

configure_all(){
  local hostname_value="$1" admin_user="$2" admin_password="$3" reset_admin="$4"
  local root_password="$5" reset_root="$6" timezone="$7" ssh_mode="$8" apply_updates="$9"

  preflight
  configure_apt
  apt_update_once
  if [[ "$apply_updates" == "1" ]]; then
    apt_upgrade_safe
  fi
  install_base_packages
  configure_admin_user "$admin_user" "$admin_password" "$reset_admin"
  configure_root_password "$root_password" "$reset_root"
  configure_hostname "$hostname_value"
  configure_time "$timezone"
  configure_security "$ssh_mode"
  configure_limits
  configure_shell
  configure_auto_updates
  configure_observability
  updatedb 2>/dev/null || true
  systemctl daemon-reload
  write_state "$hostname_value" "$admin_user" "$timezone" "$ssh_mode"
}

run_install(){
  begin_mutation install
  prompt_identity

  cat <<EOF_SUMMARY

Planned baseline:
  Hostname:       ${HOSTNAME_VALUE}
  Admin user:     ${ADMIN_USER}
  Timezone:       ${TIMEZONE_VALUE}
  SSH mode:       ${SSH_MODE}
  Initial update: $([[ "$APPLY_INITIAL_UPDATES" == "1" ]] && echo yes || echo no)

Network/netplan will NOT be modified.
Only the effective SSH port will be opened by UFW.
No automatic reboot will be performed.
EOF_SUMMARY

  local answer
  read -r -p 'Continue? [y/N]: ' answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Cancelled."

  configure_all \
    "$HOSTNAME_VALUE" "$ADMIN_USER" "$ADMIN_PASSWORD" "$RESET_ADMIN_PASSWORD" \
    "$ROOT_PASSWORD" "$RESET_ROOT_PASSWORD" "$TIMEZONE_VALUE" "$SSH_MODE" \
    "$APPLY_INITIAL_UPDATES"

  verify
}

repair(){
  begin_mutation repair
  load_state

  preflight
  configure_apt
  install_base_packages
  configure_admin_user "$ADMIN_USER" "" 0
  configure_hostname "$HOSTNAME_VALUE"
  configure_time "$TIMEZONE_VALUE"
  configure_security "$SSH_MODE"
  configure_limits
  configure_shell
  configure_auto_updates
  configure_observability
  updatedb 2>/dev/null || true
  systemctl daemon-reload
  printf '%s\n' "$SYSTEM_MANAGER_VERSION" > "${STATE_DIR}/version"
  chmod 0600 "${STATE_DIR}/version"

  verify
}

update_system(){
  begin_mutation update
  preflight
  apt_update_once
  apt_upgrade_safe
  updatedb 2>/dev/null || true
  systemctl daemon-reload
  info "Safe package upgrade completed. No automatic reboot was performed."
  if [[ -e /var/run/reboot-required ]]; then
    warn "A reboot is required: $(cat /var/run/reboot-required 2>/dev/null || true)"
  fi
}

update_full(){
  begin_mutation update-full
  preflight

  cat <<'EOF_FULL'
A full-upgrade may install/remove packages to satisfy dependency changes.
Use this only after reviewing the server and current workloads.
EOF_FULL
  local answer
  read -r -p 'Type FULL-UPGRADE to continue: ' answer
  [[ "$answer" == "FULL-UPGRADE" ]] || die "Full upgrade cancelled."

  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=600 \
    -o Acquire::Retries=5 \
    full-upgrade -y
  systemctl daemon-reload
  info "Full upgrade completed. No automatic reboot was performed."
}

cleanup_system(){
  begin_mutation cleanup
  apt_update_once
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=600 \
    autoremove --purge -y
  apt-get clean
}

set_ssh_mode(){
  begin_mutation ssh-mode
  load_state
  local mode="${1:-}"
  case "$mode" in secure|keys-only|compat) ;; *) die "Usage: system-manager ssh-mode secure|keys-only|compat" ;; esac

  if [[ "$mode" == "keys-only" ]]; then
    local admin_key=0 root_key=0
    [[ -s "/home/${ADMIN_USER}/.ssh/authorized_keys" ]] && admin_key=1
    [[ -s /root/.ssh/authorized_keys ]] && root_key=1
    (( admin_key == 1 || root_key == 1 )) || \
      die "Refusing keys-only mode: no authorized_keys found for root or ${ADMIN_USER}."
  fi

  write_ssh_policy "$mode"
  local port
  port="$(current_ssh_port)"
  configure_firewall "$port"
  systemctl reload ssh
  SSH_MODE="$mode"
  write_state "$HOSTNAME_VALUE" "$ADMIN_USER" "$TIMEZONE_VALUE" "$SSH_MODE"
  info "SSH mode changed to: $mode"
}

backup_system(){
  require_root backup
  require_ubuntu_2404
  acquire_lock

  local dest="${1:-/root/simha-system-manager-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"
  [[ "$dest" == /* ]] || die "Backup path must be absolute."

  local items=()
  local path
  for path in \
    "$STATE_DIR" \
    "$APT_POLICY_FILE" \
    /etc/apt/apt.conf.d/20auto-upgrades \
    "$UNATTENDED_FILE" \
    "$SSH_DROPIN" \
    "$FAIL2BAN_FILE" \
    "$LIMITS_FILE" \
    "$SYSTEMD_LIMITS_FILE" \
    "$SHELL_PROFILE"; do
    [[ -e "$path" ]] && items+=("${path#/}")
  done

  ((${#items[@]} > 0)) || die "No managed configuration exists to back up."
  tar --acls --xattrs --numeric-owner -C / -czf "$dest" "${items[@]}"
  chown root:root "$dest"
  chmod 0600 "$dest"
  info "Backup created: $dest"
}

status(){
  require_ubuntu_2404
  say "Manager" "$SYSTEM_MANAGER_VERSION"
  say "Hostname" "$(hostname -f 2>/dev/null || hostname)"
  say "Timezone" "$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  say "Kernel" "$(uname -r)"
  say "Uptime" "$(uptime -p 2>/dev/null || true)"

  if [[ -r "$CONFIG_FILE" ]]; then
    say "Admin user" "$(state_value ADMIN_USER)"
    say "SSH mode" "$(state_value SSH_MODE)"
  else
    say "State" "NOT CONFIGURED"
  fi

  local svc
  for svc in ssh fail2ban chrony; do
    if systemctl is-active --quiet "$svc"; then
      say "$svc" "ACTIVE"
    else
      say "$svc" "INACTIVE"
    fi
  done

  if command -v ufw >/dev/null 2>&1; then
    echo
    ufw status verbose | sed -n '1,20p'
  fi

  if [[ -e /var/run/reboot-required ]]; then
    say "Reboot" "REQUIRED"
  else
    say "Reboot" "not required"
  fi
}

verify(){
  require_root verify
  require_ubuntu_2404

  local failed=0
  echo "=== SIMHA System Manager verification ==="

  echo "[1/10] Manager / state"
  [[ -x "$MANAGER_PATH" ]] || { say "$MANAGER_PATH" MISSING; failed=1; }
  [[ -r "$CONFIG_FILE" ]] || { say "$CONFIG_FILE" MISSING; failed=1; }

  echo "[2/10] Package database"
  local dpkg_audit=""
  dpkg_audit="$(dpkg --audit 2>/dev/null || true)"
  [[ -z "$dpkg_audit" ]] || { say dpkg-audit FAILED; failed=1; }
  apt-get check >/dev/null 2>&1 || { say apt-check FAILED; failed=1; }

  echo "[3/10] Hostname / time"
  hostname -f >/dev/null 2>&1 || { say hostname-resolution FAILED; failed=1; }
  systemctl is-active --quiet chrony || { say chrony INACTIVE; failed=1; }

  echo "[4/10] SSH"
  command -v sshd >/dev/null 2>&1 || { say sshd MISSING; failed=1; }
  sshd -t >/dev/null 2>&1 || { say sshd-config FAILED; failed=1; }
  systemctl is-active --quiet ssh || { say ssh INACTIVE; failed=1; }

  echo "[5/10] Firewall"
  command -v ufw >/dev/null 2>&1 || { say ufw MISSING; failed=1; }
  ufw_is_active || { say ufw INACTIVE; failed=1; }
  local ssh_port
  ssh_port="$(current_ssh_port)"
  ufw status | grep -Eq "(^|[[:space:]])${ssh_port}/tcp([[:space:]]|$)|(^|[[:space:]])${ssh_port}([[:space:]]|$)" || \
    { say "ufw-ssh-${ssh_port}" MISSING; failed=1; }

  echo "[6/10] Fail2Ban"
  systemctl is-active --quiet fail2ban || { say fail2ban INACTIVE; failed=1; }
  fail2ban-client status sshd >/dev/null 2>&1 || { say fail2ban-sshd FAILED; failed=1; }

  echo "[7/10] Sudoers / admin"
  visudo -c >/dev/null 2>&1 || { say sudoers FAILED; failed=1; }
  if [[ -r "$CONFIG_FILE" ]]; then
    local admin
    admin="$(state_value ADMIN_USER)"
    id "$admin" >/dev/null 2>&1 || { say admin-user MISSING; failed=1; }
    local admin_groups=""
    admin_groups="$(id -nG "$admin" 2>/dev/null || true)"
    grep -Fxq sudo <<<"${admin_groups// /$'\n'}" || { say admin-sudo FAILED; failed=1; }
  fi

  echo "[8/10] Managed file permissions"
  [[ ! -e "$CONFIG_FILE" || "$(stat -c %a "$CONFIG_FILE")" == "600" ]] || { say state-permissions FAILED; failed=1; }
  [[ ! -e "$SSH_DROPIN" || "$(stat -c %a "$SSH_DROPIN")" == "644" ]] || { say ssh-permissions FAILED; failed=1; }

  echo "[9/10] Automatic updates"
  [[ -r /etc/apt/apt.conf.d/20auto-upgrades ]] || { say unattended-upgrades-config MISSING; failed=1; }
  [[ -r "$UNATTENDED_FILE" ]] || { say unattended-upgrades-policy MISSING; failed=1; }

  echo "[10/10] Network ownership boundary"
  if find /etc/netplan -maxdepth 1 -type f -name '*simha-system-manager*' -print -quit 2>/dev/null | grep -q .; then
    say netplan-boundary FAILED
    failed=1
  else
    say netplan-boundary PRESERVED
  fi

  echo
  if (( failed == 0 )); then
    echo "SYSTEM MANAGER: VERIFIED"
    echo "Manager:  $SYSTEM_MANAGER_VERSION"
    echo "SSH port: $ssh_port"
  else
    echo "SYSTEM MANAGER: VERIFICATION FAILED"
  fi
  return "$failed"
}

doctor(){
  require_root doctor
  require_ubuntu_2404

  echo "=== system-manager doctor ==="
  echo
  echo "--- OS ---"
  grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release || true
  uname -a

  echo
  echo "--- State ---"
  if [[ -r "$CONFIG_FILE" ]]; then
    sed -E 's/(PASSWORD|TOKEN|SECRET|KEY)=.*/\1=[REDACTED]/I' "$CONFIG_FILE"
  else
    echo "Not configured."
  fi

  echo
  echo "--- Services ---"
  systemctl --no-pager --full status ssh fail2ban chrony 2>/dev/null | sed -n '1,120p' || true

  echo
  echo "--- SSH effective policy ---"
  sshd -T 2>/dev/null | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowtcpforwarding|gatewayports) ' || true

  echo
  echo "--- Firewall ---"
  ufw status verbose 2>/dev/null || true

  echo
  echo "--- Fail2Ban ---"
  fail2ban-client status sshd 2>/dev/null || true

  echo
  echo "--- Time ---"
  timedatectl 2>/dev/null || true
  chronyc tracking 2>/dev/null || true

  echo
  echo "--- Package health ---"
  dpkg --audit 2>/dev/null || true
  apt-get check 2>&1 || true

  echo
  echo "--- Disk / memory ---"
  df -h /
  free -h

  echo
  echo "--- Reboot ---"
  if [[ -e /var/run/reboot-required ]]; then
    cat /var/run/reboot-required
    cat /var/run/reboot-required.pkgs 2>/dev/null || true
  else
    echo "No reboot required marker."
  fi
}

show_version(){
  echo "system-manager $SYSTEM_MANAGER_VERSION"
}

help(){
  cat <<EOF_HELP
SIMHA System Manager v${SYSTEM_MANAGER_VERSION}
Ubuntu Server 24.04 LTS

Usage:
  sudo system-manager <command>

Commands:
  install | configure          Initial interactive baseline configuration
  repair                       Reapply managed baseline without changing passwords
  update                       Safe apt package upgrade; never reboots automatically
  update-full                  Explicit confirmed apt full-upgrade
  cleanup                      Autoremove unused packages and clean apt cache
  ssh-mode MODE                secure | keys-only | compat
  backup [ABSOLUTE_FILE]       Back up system-manager-owned configuration
  status                       Concise OS/security status
  verify                       Deterministic managed-baseline verification
  doctor                       Extended diagnostics
  version                      Show manager version
  help

Default SSH policy (secure):
  PermitRootLogin prohibit-password
  PasswordAuthentication yes
  PubkeyAuthentication yes
  AllowTcpForwarding yes

Important boundaries:
  - Does not modify /etc/netplan or provider IP configuration.
  - Opens only the effective SSH port in UFW.
  - Nginx/WireGuard/Docker managers own their application-specific networking.
  - Does not automatically reboot.
  - Repair never resets root or admin passwords.
EOF_HELP
}

main(){
  local command="${1:-help}"
  case "$command" in
    help|-h|--help) help ;;
    version|versions) show_version ;;
    install|configure) run_install ;;
    repair) repair ;;
    update) update_system ;;
    update-full) update_full ;;
    cleanup) cleanup_system ;;
    ssh-mode) shift; set_ssh_mode "${1:-}" ;;
    backup) shift; backup_system "${1:-}" ;;
    status) require_root status; status ;;
    verify) verify ;;
    doctor) doctor ;;
    *) help >&2; die "Unknown command: $command" ;;
  esac
}

main "$@"
