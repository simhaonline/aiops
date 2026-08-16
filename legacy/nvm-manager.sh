#!/usr/bin/env bash
# LEGACY SUPPORT SNAPSHOT
# Suite archive: pre-1.0.1 internal manager lineage
# This file is NOT installed on PATH and is preserved for rollback/reference only.
readonly AIOPS_LEGACY_RELEASE="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 022

# =============================================================================
# NVM / Node.js / PM2 Manager for Ubuntu 24.04 LTS
# Manager version: 3.1.0
#
# Clean per-user lifecycle manager. No dedicated service account is required.
# Default target user: root
# Override explicitly when needed:
#   NVM_USER=deploy nvm-manager install
#
# Design goals:
#   - security: strict validation, no curl|bash, no eval, pinned NVM release,
#               serialized mutations, safe destructive-operation checks
#   - performance: shallow NVM checkout, Node binary downloads, lazy shell
#                  loading, direct default Node/PM2 PATH, low-overhead commands
#   - stability: current Node LTS by default, compatible npm, package migration,
#                atomic profile edits, verification after lifecycle operations
#
# Managed files:
#   <home>/.nvm
#   <home>/.bashrc              (one marked block)
#   /usr/local/bin/nvm-manager
# =============================================================================

readonly MANAGER_VERSION="3.1.0"
readonly MANAGER_PATH="/usr/local/bin/nvm-manager"
readonly NVM_REPOSITORY="https://github.com/nvm-sh/nvm.git"
readonly PROFILE_BEGIN="# >>> NVM MANAGER BLOCK >>>"
readonly PROFILE_END="# <<< NVM MANAGER BLOCK <<<"
readonly LOCK_FILE="/run/lock/nvm-manager.lock"

NVM_USER="${NVM_USER:-root}"
NVM_VERSION="${NVM_VERSION:-v0.40.6}"
NODE_DEFAULT="${NODE_DEFAULT:-lts/*}"
PM2_VERSION="${PM2_VERSION:-latest}"
NVM_NODEJS_ORG_MIRROR="${NVM_NODEJS_ORG_MIRROR:-https://nodejs.org/dist}"

log()  { printf '\n==> %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '[ERROR] Command failed at line %s (exit %s).\n' "${BASH_LINENO[0]:-?}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this manager as root."
}

require_ubuntu_2404() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || die "Supported OS: Ubuntu 24.04 LTS. Found: ${PRETTY_NAME:-unknown}."
  [[ "${VERSION_ID:-}" == "24.04" ]] || die "Supported OS: Ubuntu 24.04 LTS. Found: ${PRETTY_NAME:-unknown}."
}

validate_config() {
  [[ "$NVM_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "Invalid NVM_USER: $NVM_USER"
  [[ "$NVM_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "NVM_VERSION must be a release tag such as v0.40.6."
  [[ -n "$NODE_DEFAULT" && "$NODE_DEFAULT" != *$'\n'* && "$NODE_DEFAULT" != *$'\r'* ]] || die "Invalid NODE_DEFAULT."
  [[ "$PM2_VERSION" =~ ^(latest|[0-9]+([.][0-9]+){0,2}([+-][A-Za-z0-9._-]+)?)$ ]] || die "Invalid PM2_VERSION: $PM2_VERSION"
  [[ "$NVM_NODEJS_ORG_MIRROR" == https://* ]] || die "NVM_NODEJS_ORG_MIRROR must use HTTPS."
}

require_user() {
  getent passwd "$NVM_USER" >/dev/null || die "Linux user '$NVM_USER' does not exist."
}

user_home() {
  local home
  home="$(getent passwd "$NVM_USER" | awk -F: '{print $6}')"
  [[ -n "$home" && "$home" == /* && "$home" != "/" ]] || die "Unsafe home directory for '$NVM_USER': ${home:-empty}"
  printf '%s\n' "$home"
}

user_group() {
  id -gn "$NVM_USER"
}

nvm_dir() {
  printf '%s/.nvm\n' "$(user_home)"
}

bashrc_file() {
  printf '%s/.bashrc\n' "$(user_home)"
}

assert_safe_nvm_dir() {
  local home dir
  home="$(user_home)"
  dir="$(nvm_dir)"
  [[ "$dir" == "$home/.nvm" && "$dir" != "/.nvm" ]] || die "Refusing unsafe NVM directory: $dir"
  [[ ! -L "$dir" ]] || die "Refusing to manage symlinked NVM directory: $dir"
}

acquire_lock() {
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "Another nvm-manager process is already running."
}

install_dependencies() {
  local missing=()
  local cmd
  for cmd in git curl tar xz flock awk sed grep; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if ((${#missing[@]} == 0)); then
    return 0
  fi

  log "Installing required system packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates curl git tar xz-utils util-linux gawk
}

self_install() {
  local source_path
  source_path="$(readlink -f "${BASH_SOURCE[0]}")"
  [[ "$source_path" == "$MANAGER_PATH" ]] && return 0
  install -o root -g root -m 0755 "$source_path" "$MANAGER_PATH"
  info "Manager installed: $MANAGER_PATH"
}

run_user_shell() {
  require_user

  local home
  home="$(user_home)"

  runuser -u "$NVM_USER" -- \
    env -i \
      HOME="$home" \
      USER="$NVM_USER" \
      LOGNAME="$NVM_USER" \
      SHELL="/bin/bash" \
      LANG="C.UTF-8" \
      LC_ALL="C.UTF-8" \
      NVM_DIR="$home/.nvm" \
      NVM_NODEJS_ORG_MIRROR="$NVM_NODEJS_ORG_MIRROR" \
      NVM_NO_COLORS="1" \
      npm_config_fund="false" \
      npm_config_update_notifier="false" \
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    bash --noprofile --norc -c '
      set -Eeuo pipefail
      mode="$1"
      shift
      cd "$HOME"

      case "$mode" in
        nvm)
          [[ -s "$NVM_DIR/nvm.sh" ]] || {
            printf "ERROR: %s/nvm.sh is missing.\n" "$NVM_DIR" >&2
            exit 1
          }
          # shellcheck disable=SC1090
          . "$NVM_DIR/nvm.sh" --no-use
          nvm "$@"
          ;;
        cmd)
          command "$@"
          ;;
        nodecmd)
          [[ -s "$NVM_DIR/nvm.sh" ]] || {
            printf "ERROR: %s/nvm.sh is missing.\n" "$NVM_DIR" >&2
            exit 1
          }
          # shellcheck disable=SC1090
          . "$NVM_DIR/nvm.sh" --no-use
          nvm use default >/dev/null
          command "$@"
          ;;
        *)
          printf "ERROR: invalid internal execution mode.\n" >&2
          exit 2
          ;;
      esac
    ' bash "$@"
}

run_nvm() {
  run_user_shell nvm "$@"
}

run_user_cmd() {
  run_user_shell cmd "$@"
}

run_node_cmd() {
  run_user_shell nodecmd "$@"
}

remove_managed_profile_block() {
  local bashrc tmp uid gid mode
  bashrc="$(bashrc_file)"
  [[ -f "$bashrc" ]] || return 0

  uid="$(id -u "$NVM_USER")"
  gid="$(id -g "$NVM_USER")"
  mode="$(stat -c '%a' "$bashrc")"
  tmp="$(mktemp "${bashrc}.tmp.XXXXXX")"

  awk -v begin="$PROFILE_BEGIN" -v end="$PROFILE_END" '
    $0 == begin { inside=1; next }
    inside && $0 == end { inside=0; next }
    !inside { print }
  ' "$bashrc" > "$tmp"

  [[ -s "$tmp" ]] && printf '\n' >> "$tmp"

  chown "$uid:$gid" "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$bashrc"
}

write_managed_profile_block() {
  local home bashrc tmp uid gid mode
  home="$(user_home)"
  bashrc="$(bashrc_file)"
  uid="$(id -u "$NVM_USER")"
  gid="$(id -g "$NVM_USER")"

  if [[ ! -e "$bashrc" ]]; then
    install -o "$uid" -g "$gid" -m 0644 /dev/null "$bashrc"
  fi

  remove_managed_profile_block
  mode="$(stat -c '%a' "$bashrc")"
  tmp="$(mktemp "${bashrc}.tmp.XXXXXX")"
  cat "$bashrc" > "$tmp"

  cat >> "$tmp" <<EOF_PROFILE
$PROFILE_BEGIN
export NVM_DIR="$home/.nvm"

# Fast path: Node.js, npm, npx and PM2 are usable without sourcing nvm.sh.
if [ -d "\$NVM_DIR/default-bin" ]; then
  case ":\$PATH:" in
    *":\$NVM_DIR/default-bin:"*) ;;
    *) export PATH="\$NVM_DIR/default-bin:\$PATH" ;;
  esac
fi

# Lazy-load NVM only when the nvm command itself is used.
nvm() {
  unset -f nvm
  if [ ! -s "\$NVM_DIR/nvm.sh" ]; then
    echo "NVM is not installed at \$NVM_DIR" >&2
    return 127
  fi
  . "\$NVM_DIR/nvm.sh" --no-use
  nvm "\$@"
}
$PROFILE_END
EOF_PROFILE

  chown "$uid:$gid" "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$bashrc"
}

verify_nvm_checkout() {
  local dir origin tag head tag_commit
  dir="$(nvm_dir)"

  [[ -s "$dir/nvm.sh" ]] || die "NVM runtime is incomplete: $dir/nvm.sh is missing."
  [[ -d "$dir/.git" ]] || die "NVM directory is not a Git checkout: $dir"

  origin="$(run_user_cmd git -C "$dir" remote get-url origin)"
  [[ "$origin" == "$NVM_REPOSITORY" ]] || die "Unexpected NVM Git origin: $origin"

  tag="$(run_user_cmd git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
  [[ "$tag" == "$NVM_VERSION" ]] || die "NVM checkout is not pinned to $NVM_VERSION (found: ${tag:-untagged})."

  head="$(run_user_cmd git -C "$dir" rev-parse HEAD)"
  tag_commit="$(run_user_cmd git -C "$dir" rev-list -n 1 "$NVM_VERSION")"
  [[ "$head" == "$tag_commit" ]] || die "NVM checkout commit does not match $NVM_VERSION."
}

install_nvm_runtime() {
  local dir parent uid gid
  dir="$(nvm_dir)"
  parent="$(dirname "$dir")"
  uid="$(id -u "$NVM_USER")"
  gid="$(id -g "$NVM_USER")"

  assert_safe_nvm_dir
  [[ ! -e "$dir" ]] || die "NVM directory already exists: $dir. Use 'update' or 'reinstall'."

  install -d -o "$uid" -g "$gid" -m 0755 "$parent"

  log "Installing NVM $NVM_VERSION"
  run_user_cmd git clone \
    --quiet \
    --depth 1 \
    --branch "$NVM_VERSION" \
    --single-branch \
    "$NVM_REPOSITORY" "$dir"

  verify_nvm_checkout
}

update_nvm_runtime() {
  local dir
  dir="$(nvm_dir)"
  assert_safe_nvm_dir

  [[ -d "$dir/.git" && -s "$dir/nvm.sh" ]] || die "NVM is not installed as a managed Git checkout. Use 'reinstall'."

  log "Updating NVM runtime to $NVM_VERSION"
  run_user_cmd git -C "$dir" remote set-url origin "$NVM_REPOSITORY"
  run_user_cmd git -C "$dir" fetch --quiet --force --depth 1 origin "refs/tags/$NVM_VERSION:refs/tags/$NVM_VERSION"
  run_user_cmd git -C "$dir" checkout --quiet --detach "$NVM_VERSION"
  run_user_cmd git -C "$dir" reset --quiet --hard "$NVM_VERSION"
  verify_nvm_checkout
}

refresh_default_bin_link() {
  local dir resolved target link
  dir="$(nvm_dir)"
  resolved="$(run_nvm version default 2>/dev/null || true)"
  [[ "$resolved" == v* ]] || die "Unable to resolve NVM default alias."

  target="$dir/versions/node/$resolved/bin"
  link="$dir/default-bin"
  [[ -d "$target" ]] || die "Default Node.js bin directory is missing: $target"

  run_user_cmd ln -sfn "$target" "$link"
}

configure_node_defaults() {
  local old_version new_version
  old_version="$(run_nvm version default 2>/dev/null || true)"

  log "Installing/updating default Node.js target: $NODE_DEFAULT"
  run_nvm install "$NODE_DEFAULT" --latest-npm
  new_version="$(run_nvm version "$NODE_DEFAULT")"

  if [[ "$old_version" == v* && "$old_version" != "$new_version" ]]; then
    log "Migrating global packages from $old_version to $new_version"
    if ! run_nvm reinstall-packages "$old_version"; then
      warn "Some global packages could not be migrated; continuing with the new Node.js runtime."
    fi
  fi

  run_nvm alias default "$NODE_DEFAULT" >/dev/null
  run_nvm use default >/dev/null
  refresh_default_bin_link
}

install_or_update_pm2() {
  log "Installing/updating PM2@$PM2_VERSION"
  run_node_cmd npm install --global "pm2@$PM2_VERSION"
  run_node_cmd pm2 --version >/dev/null
}

install_nvm() {
  require_ubuntu_2404
  require_user
  install_dependencies
  assert_safe_nvm_dir

  log "NVM / Node.js installation for user '$NVM_USER'"
  install_nvm_runtime
  write_managed_profile_block
  configure_node_defaults
  install_or_update_pm2
  self_install
  verify_nvm

  log "Installation complete"
}

update_nvm() {
  require_ubuntu_2404
  require_user
  install_dependencies
  assert_safe_nvm_dir

  update_nvm_runtime
  write_managed_profile_block
  configure_node_defaults
  install_or_update_pm2
  self_install
  verify_nvm

  log "Update complete"
}

reinstall_nvm() {
  require_ubuntu_2404
  require_user
  install_dependencies
  assert_safe_nvm_dir

  local dir backup uid gid item
  dir="$(nvm_dir)"
  uid="$(id -u "$NVM_USER")"
  gid="$(id -g "$NVM_USER")"
  backup="$(mktemp -d /tmp/nvm-manager-backup.XXXXXX)"

  log "Reinstalling NVM runtime while preserving Node.js versions and aliases"

  if [[ -d "$dir" ]]; then
    for item in versions alias .cache default-packages; do
      [[ -e "$dir/$item" ]] && cp -a "$dir/$item" "$backup/"
    done
    rm -rf -- "$dir"
  fi

  install_nvm_runtime

  for item in versions alias .cache default-packages; do
    if [[ -e "$backup/$item" ]]; then
      rm -rf -- "$dir/$item"
      cp -a "$backup/$item" "$dir/"
    fi
  done
  chown -R "$uid:$gid" "$dir"

  write_managed_profile_block
  configure_node_defaults
  install_or_update_pm2
  self_install
  verify_nvm

  rm -rf -- "$backup"
  log "Reinstall complete"
}

disable_nvm() {
  require_user
  log "Removing managed shell integration"
  remove_managed_profile_block
  info "NVM data preserved: $(nvm_dir)"
  info "Running PM2 processes are not stopped or modified."
}

purge_nvm() {
  require_user
  assert_safe_nvm_dir

  local dir confirmation
  dir="$(nvm_dir)"

  cat <<EOF_PURGE

DESTRUCTIVE OPERATION

This permanently deletes:
  $dir

It removes all NVM-managed Node.js versions, global npm packages, PM2 binaries,
aliases and NVM caches for user '$NVM_USER'. Application/project files outside
that directory are not deleted.
EOF_PURGE

  read -r -p "Type DELETE-NVM-NODE-DATA to continue: " confirmation
  [[ "$confirmation" == "DELETE-NVM-NODE-DATA" ]] || die "Purge cancelled."

  remove_managed_profile_block

  if [[ -s "$dir/nvm.sh" ]]; then
    run_node_cmd pm2 kill >/dev/null 2>&1 || true
  fi

  rm -rf -- "$dir"
  info "NVM/Node.js data permanently deleted: $dir"
}

status_nvm() {
  require_user

  local dir bashrc
  dir="$(nvm_dir)"
  bashrc="$(bashrc_file)"

  echo "=== NVM Manager ==="
  echo "Manager:       $MANAGER_PATH"
  echo "Target user:   $NVM_USER"
  echo "Home:          $(user_home)"
  echo "NVM directory: $dir"
  echo "NVM target:    $NVM_VERSION"
  echo "Node default:  $NODE_DEFAULT"
  echo

  if [[ ! -s "$dir/nvm.sh" ]]; then
    echo "NVM: NOT INSTALLED"
    return 0
  fi

  echo "=== Versions ==="
  printf 'NVM:  '
  run_nvm --version
  printf 'Node: '
  run_node_cmd node --version
  printf 'npm:  '
  run_node_cmd npm --version
  printf 'PM2:  '
  run_node_cmd pm2 --version 2>/dev/null || echo "not installed"

  echo
  echo "=== Default alias ==="
  run_nvm alias default || true

  echo
  echo "=== Installed Node.js versions ==="
  run_nvm ls

  echo
  echo "=== Shell integration ==="
  if [[ -f "$bashrc" ]] && grep -Fq "$PROFILE_BEGIN" "$bashrc"; then
    echo "Managed block: PRESENT ($bashrc)"
  else
    echo "Managed block: NOT PRESENT"
  fi

  echo
  echo "=== PM2 ==="
  run_node_cmd pm2 status || true
}

verify_nvm() {
  require_user
  assert_safe_nvm_dir

  local dir bashrc nvm_v node_v npm_v pm2_v default_v link_target owner mode count
  dir="$(nvm_dir)"
  bashrc="$(bashrc_file)"

  [[ -s "$dir/nvm.sh" ]] || die "NVM is not installed at $dir."
  verify_nvm_checkout

  [[ -f "$bashrc" ]] || die "Bash profile does not exist: $bashrc"
  count="$(grep -Fc "$PROFILE_BEGIN" "$bashrc" || true)"
  [[ "$count" == "1" ]] || die "Expected exactly one managed profile block; found $count."
  grep -Fq "$PROFILE_END" "$bashrc" || die "Managed profile block is incomplete."

  owner="$(stat -c '%U' "$dir")"
  [[ "$owner" == "$NVM_USER" ]] || die "NVM directory owner is '$owner', expected '$NVM_USER'."

  mode="$(stat -c '%A' "$dir")"
  [[ "$mode" != ?????w???? && "$mode" != ????????w? ]] || die "NVM directory is writable by group or others: $mode"

  nvm_v="$(run_nvm --version)"
  node_v="$(run_node_cmd node --version)"
  npm_v="$(run_node_cmd npm --version)"
  pm2_v="$(run_node_cmd pm2 --version)"
  default_v="$(run_nvm version default)"

  [[ "v$nvm_v" == "$NVM_VERSION" ]] || die "Loaded NVM version v$nvm_v does not match $NVM_VERSION."
  [[ "$node_v" == v* ]] || die "Node.js version check failed."
  [[ -n "$npm_v" ]] || die "npm version check failed."
  [[ -n "$pm2_v" ]] || die "PM2 version check failed."
  [[ "$default_v" == "$node_v" ]] || die "Default alias ($default_v) does not match active Node.js ($node_v)."

  [[ -L "$dir/default-bin" ]] || die "Fast-path default-bin symlink is missing."
  link_target="$(readlink -f "$dir/default-bin")"
  [[ "$link_target" == "$dir/versions/node/$default_v/bin" ]] || die "default-bin points to an unexpected location: $link_target"

  [[ "$(run_node_cmd node -p 'process.execPath.startsWith(process.env.NVM_DIR)')" == "true" ]] || die "Node.js is not running from NVM."
  [[ "$(run_node_cmd node -p 'process.versions.node')" == "${node_v#v}" ]] || die "Node.js execution verification failed."

  echo "NVM/NODE/NPM/PM2: VERIFIED"
  echo "User: $NVM_USER"
  echo "NVM:  $nvm_v"
  echo "Node: $node_v"
  echo "npm:  $npm_v"
  echo "PM2:  $pm2_v"
}

show_nvm_version() {
  require_user
  [[ -s "$(nvm_dir)/nvm.sh" ]] || die "NVM is not installed."
  run_nvm --version
}

show_node_version() {
  require_user
  [[ -s "$(nvm_dir)/nvm.sh" ]] || die "NVM is not installed."
  run_node_cmd node --version
}

list_nodes() {
  require_user
  [[ -s "$(nvm_dir)/nvm.sh" ]] || die "NVM is not installed."
  run_nvm ls
}

install_node() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "Usage: nvm-manager install-node VERSION"
  run_nvm install "$version" --latest-npm
}

uninstall_node() {
  local version="${1:-}" answer default_v resolved
  [[ -n "$version" ]] || die "Usage: nvm-manager uninstall-node VERSION"

  resolved="$(run_nvm version "$version" 2>/dev/null || true)"
  default_v="$(run_nvm version default 2>/dev/null || true)"
  [[ "$resolved" == v* ]] || die "Node.js target '$version' is not installed."
  [[ "$resolved" != "$default_v" ]] || die "Refusing to uninstall the current default Node.js version ($default_v). Set another default first."

  read -r -p "Uninstall Node.js '$resolved'? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "Node.js uninstall cancelled."
  run_nvm uninstall "$resolved"
}

use_node() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "Usage: nvm-manager use VERSION"
  run_nvm use "$version"
  warn "'use' affects only this manager subprocess. Use 'set-default VERSION' for persistent shells."
}

set_default() {
  local version="${1:-}"
  [[ -n "$version" ]] || die "Usage: nvm-manager set-default VERSION"

  run_nvm install "$version" --latest-npm
  run_nvm alias default "$version" >/dev/null
  run_nvm use default >/dev/null
  refresh_default_bin_link
  info "Default Node.js target set to: $version ($(run_nvm version default))"
}

install_lts() {
  NODE_DEFAULT="lts/*"
  configure_node_defaults
  install_or_update_pm2
  verify_nvm
}

update_npm() {
  run_nvm use default >/dev/null
  run_nvm install-latest-npm
  run_node_cmd npm --version
}

install_pm2() {
  install_or_update_pm2
  run_node_cmd pm2 --version
}

pm2_status() {
  run_node_cmd pm2 status
}

clean_cache() {
  log "Cleaning NVM download cache"
  run_nvm cache clear
  log "Verifying npm cache"
  run_node_cmd npm cache verify
}

repair_nvm() {
  local uid gid dir
  uid="$(id -u "$NVM_USER")"
  gid="$(id -g "$NVM_USER")"
  dir="$(nvm_dir)"

  [[ -d "$dir" ]] || die "NVM is not installed."
  assert_safe_nvm_dir
  chown -R "$uid:$gid" "$dir"
  write_managed_profile_block
  run_nvm use default >/dev/null
  refresh_default_bin_link
  verify_nvm
}

show_manager_version() {
  echo "nvm-manager $MANAGER_VERSION"
  echo "nvm-release $NVM_VERSION"
  if [[ -x "$(default_bin_dir)/node" ]]; then "$(default_bin_dir)/node" --version 2>/dev/null || true; fi
}

help_text() {
  cat <<EOF_HELP
NVM / Node.js / PM2 Manager v$MANAGER_VERSION

Usage:
  nvm-manager <command> [arguments]

Target user:
  Default: root
  Override: NVM_USER=<user> nvm-manager <command>

Lifecycle:
  install               Install pinned NVM, current Node.js LTS, compatible npm and PM2
  update                Update NVM/runtime, refresh Node LTS and migrate global packages
  reinstall             Rebuild NVM runtime while preserving Node versions/aliases/cache
  disable               Remove only the managed ~/.bashrc integration; preserve all data
  purge                 Permanently delete the target user's entire ~/.nvm tree
  repair                Repair ownership/profile/default fast-path and verify

Inspection:
  status
  verify
  manager-version
  version
  node-version
  list

Node.js:
  install-node VERSION
  uninstall-node VERSION
  use VERSION            Temporary manager subprocess only
  set-default VERSION    Persistent default for interactive shells/services
  install-lts
  update-npm

PM2:
  install-pm2
  pm2-status

Maintenance:
  clean-cache

Defaults:
  User:          $NVM_USER
  NVM release:   $NVM_VERSION
  Node default:  $NODE_DEFAULT
  PM2:           $PM2_VERSION
  Node mirror:   $NVM_NODEJS_ORG_MIRROR

Examples:
  nvm-manager install
  nvm-manager status
  nvm-manager update
  nvm-manager install-node 24
  nvm-manager set-default 24
  NVM_USER=deploy nvm-manager install

Security / performance notes:
  - NVM is installed per-user; no dedicated service account is created or required.
  - The default target is root, so the default NVM directory is /root/.nvm.
  - NVM is cloned from a pinned Git tag; no downloaded installer is piped to a shell.
  - Manager commands never use eval for Node/NVM arguments.
  - Mutating commands are serialized with an exclusive lock.
  - Interactive shells use a direct default-bin PATH and lazy-load nvm.sh only when
    the 'nvm' function is called, reducing normal shell startup overhead.
  - npm audit is not globally disabled.
  - 'disable' never stops PM2 applications. 'purge' is destructive and confirmed.
EOF_HELP
}

main() {
  require_root
  validate_config
  acquire_lock

  local command="${1:-help}"
  case "$command" in
    install) install_nvm ;;
    update) update_nvm ;;
    reinstall) reinstall_nvm ;;
    disable|delete|remove|uninstall) disable_nvm ;;
    purge) purge_nvm ;;
    repair) repair_nvm ;;
    status) status_nvm ;;
    verify) verify_nvm ;;
    manager-version) show_manager_version ;;
    version) show_nvm_version ;;
    node-version) show_node_version ;;
    list|list-node|list-nodes) list_nodes ;;
    install-node)
      shift
      install_node "${1:-}"
      ;;
    uninstall-node)
      shift
      uninstall_node "${1:-}"
      ;;
    use)
      shift
      use_node "${1:-}"
      ;;
    set-default)
      shift
      set_default "${1:-}"
      ;;
    install-lts) install_lts ;;
    update-npm) update_npm ;;
    install-pm2) install_pm2 ;;
    pm2-status) pm2_status ;;
    clean-cache) clean_cache ;;
    help|-h|--help) help_text ;;
    *)
      help_text
      echo
      die "Unknown command: $command"
      ;;
  esac
}

main "$@"
