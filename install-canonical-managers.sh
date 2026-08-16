#!/usr/bin/env bash
readonly INSTALLER_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

readonly RELEASE_VERSION="1.0.1"

readonly MANAGERS=(
  system-manager
  docker-manager
  forgejo-manager
  forgejo-runner-manager
  gvm-manager
  miniconda-manager
  nvm-manager
  ollama-manager
  nginx-manager
  wireguard-manager
  harness-manager
  hermes-manager
  codex-manager
  claude-manager
  opencode-manager
  freebuff-manager
  litellm-manager
  llmrouter-manager
  project-manager
  manager-suite
)

die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
log(){ printf '[INFO] %s\n' "$*"; }

BASE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${BASE}/scripts"
LEGACY_SRC="${BASE}/legacy"
CHECKSUM_FILE="${BASE}/SHA256SUMS.txt"

CHECK_ONLY=no
INSTALL_LEGACY="${AIOPS_INSTALL_LEGACY:-0}"

usage(){
  cat <<EOF
SIMHA AiOps canonical manager installer v${INSTALLER_VERSION}

Usage:
  bash ./install-canonical-managers.sh --check
  sudo bash ./install-canonical-managers.sh all
  sudo bash ./install-canonical-managers.sh MANAGER [MANAGER...]

Environment:
  AIOPS_INSTALL_LEGACY=1   validate/copy read-only legacy support snapshots

Install mode copies manager SCRIPT files only. It never installs, repairs,
starts, restarts, updates or purges managed runtimes/services.
EOF
}

require_ubuntu(){
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || \
    die "Ubuntu 24.04 LTS required; found ${PRETTY_NAME:-unknown}."
}

dest_for(){
  case "$1" in
    wireguard-manager) printf '/usr/local/sbin/wireguard-manager\n' ;;
    *) printf '/usr/local/bin/%s\n' "$1" ;;
  esac
}

known_manager(){
  local candidate
  for candidate in "${MANAGERS[@]}"; do
    [[ "$candidate" == "$1" ]] && return 0
  done
  return 1
}

verify_version(){
  local name="$1" file="${SRC}/$1"
  case "$name" in
    system-manager) grep -Fq 'readonly SYSTEM_MANAGER_VERSION="1.0.1"' "$file" ;;
    harness-manager) grep -Fq 'readonly HM_VERSION="1.0.1"' "$file" ;;
    hermes-manager) grep -Fq 'readonly HERMES_MANAGER_VERSION="1.0.1"' "$file" ;;
    nginx-manager) grep -Fq 'readonly NGM_VERSION="1.0.1"' "$file" ;;
    manager-suite) grep -Fq 'readonly SUITE_VERSION="1.0.1"' "$file" ;;
    *) grep -Eq '(^readonly )?MANAGER_VERSION="1\.0\.1"$' "$file" ;;
  esac || die "$name is not release version 1.0.1."
}

verify_source(){
  local name="$1" file="${SRC}/$1"
  [[ -f "$file" ]] || die "Missing source: scripts/$name"
  [[ -s "$file" ]] || die "Empty source: scripts/$name"
  bash -n "$file" || die "Syntax validation failed: scripts/$name"
  "$file" help >/dev/null 2>&1 || die "Help smoke test failed: scripts/$name"
  verify_version "$name"

  if [[ -f "$CHECKSUM_FILE" ]]; then
    local expected actual
    expected="$(awk -v f="scripts/$name" '$2==f {print $1}' "$CHECKSUM_FILE" | head -n1)"
    [[ -n "$expected" ]] || die "Checksum entry missing: scripts/$name"
    actual="$(sha256sum "$file" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || die "Checksum mismatch: scripts/$name"
  fi
}

verify_legacy_sources(){
  [[ -d "$LEGACY_SRC" ]] || die "Missing legacy support directory."
  [[ -f "$LEGACY_SRC/README.md" ]] || die "Missing legacy/README.md."

  local count f rel expected actual
  count="$(find "$LEGACY_SRC" -maxdepth 1 -type f -name '*.sh' | wc -l)"
  [[ "$count" -eq 17 ]] || die "Expected 17 legacy support scripts; found $count."

  while IFS= read -r -d '' f; do
    bash -n "$f" || die "Syntax validation failed: ${f#$BASE/}"
    grep -Fq 'readonly AIOPS_LEGACY_RELEASE="1.0.1"' "$f" || \
      die "Legacy support release marker missing: ${f#$BASE/}"

    if [[ -f "$CHECKSUM_FILE" ]]; then
      rel="${f#$BASE/}"
      expected="$(awk -v p="$rel" '$2==p {print $1}' "$CHECKSUM_FILE" | head -n1)"
      [[ -n "$expected" ]] || die "Checksum entry missing: $rel"
      actual="$(sha256sum "$f" | awk '{print $1}')"
      [[ "$actual" == "$expected" ]] || die "Checksum mismatch: $rel"
    fi
  done < <(find "$LEGACY_SRC" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)

  if [[ -f "$CHECKSUM_FILE" ]]; then
    expected="$(awk '$2=="legacy/README.md" {print $1}' "$CHECKSUM_FILE" | head -n1)"
    [[ -n "$expected" ]] || die "Checksum entry missing: legacy/README.md"
    actual="$(sha256sum "$LEGACY_SRC/README.md" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || die "Checksum mismatch: legacy/README.md"
  fi
}

backup_existing(){
  local src="$1" backup_root="$2" target
  [[ -e "$src" || -L "$src" ]] || return 0
  target="${backup_root}${src}"
  install -d -m 0700 "$(dirname "$target")"
  cp -a -- "$src" "$target"
}

install_one(){
  local name="$1" src="${SRC}/$1" dest stale=""
  dest="$(dest_for "$name")"

  install -d -m 0755 "$(dirname "$dest")"
  install -o root -g root -m 0755 "$src" "$dest"

  case "$dest" in
    /usr/local/bin/*) stale="/usr/local/sbin/$name" ;;
    /usr/local/sbin/*) stale="/usr/local/bin/$name" ;;
  esac
  if [[ -n "$stale" && ( -e "$stale" || -L "$stale" ) ]]; then
    rm -f -- "$stale"
  fi

  log "Installed $name -> $dest"
}

install_legacy(){
  [[ "$INSTALL_LEGACY" != 0 ]] || return 0
  local dst="/usr/local/share/simha-aiops/legacy"
  install -d -o root -g root -m 0755 "$dst"
  find "$dst" -mindepth 1 -maxdepth 1 -type f -delete 2>/dev/null || true

  local f
  while IFS= read -r -d '' f; do
    install -o root -g root -m 0644 "$f" "$dst/$(basename "$f")"
  done < <(find "$LEGACY_SRC" -maxdepth 1 -type f -print0 | sort -z)

  log "Installed read-only legacy support snapshots -> $dst"
}

main(){
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
    usage
    exit 0
  fi

  if [[ "${1:-}" == "--check" || "${1:-}" == "check" ]]; then
    CHECK_ONLY=yes
    shift
  fi

  local selected=()
  if [[ "$CHECK_ONLY" == yes ]]; then
    (($# == 0)) || die "--check does not accept manager names."
    selected=("${MANAGERS[@]}")
  else
    (($# > 0)) || { usage; exit 2; }
    if [[ "$1" == all ]]; then
      (($# == 1)) || die "'all' cannot be combined with manager names."
      selected=("${MANAGERS[@]}")
    else
      selected=("$@")
    fi
  fi

  local manager
  for manager in "${selected[@]}"; do
    known_manager "$manager" || die "Unknown manager: $manager"
    verify_source "$manager"
  done

  if [[ "$INSTALL_LEGACY" != 0 ]]; then
    verify_legacy_sources
  fi

  if [[ "$CHECK_ONLY" == yes ]]; then
    log "Release check passed: ${#selected[@]} maintained managers, version ${RELEASE_VERSION}."
    [[ "$INSTALL_LEGACY" == 0 ]] || log "Legacy support validation passed."
    exit 0
  fi

  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Install mode requires root/sudo."
  require_ubuntu

  local stamp backup_root
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_root="/var/backups/simha-aiops/manager-scripts/${stamp}"
  install -d -o root -g root -m 0700 "$backup_root"

  for manager in "${selected[@]}"; do
    backup_existing "$(dest_for "$manager")" "$backup_root"
    case "$(dest_for "$manager")" in
      /usr/local/bin/*) backup_existing "/usr/local/sbin/$manager" "$backup_root" ;;
      /usr/local/sbin/*) backup_existing "/usr/local/bin/$manager" "$backup_root" ;;
    esac
  done

  for manager in "${selected[@]}"; do
    install_one "$manager"
  done

  install_legacy

  log "Manager-script backup: $backup_root"
  log "Canonical manager installation complete."
  log "Runtime services were not modified."
}

main "$@"
