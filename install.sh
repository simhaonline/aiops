#!/usr/bin/env bash
readonly INSTALLER_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

readonly RELEASE_VERSION="1.0.1"

REPOSITORY="${AIOPS_REPOSITORY:-simhaonline/aiops}"
REF="${AIOPS_REF:-main}"
REQUIRE_PIN="${AIOPS_REQUIRE_PIN:-0}"
DRY_RUN="${AIOPS_DRY_RUN:-0}"

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

TMP_DIR="$(mktemp -d)"
TMP_LOG="${TMP_DIR}/installer.log"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FINAL_LOG="/var/log/simha-aiops/install-${STAMP}.log"
RESOLVED_REF=""

say(){ printf '[aiops-installer] %s\n' "$*"; }
warn(){ printf '[aiops-installer] WARNING: %s\n' "$*" >&2; }
die(){ printf '[aiops-installer] ERROR: %s\n' "$*" >&2; exit 1; }

cleanup(){
  local rc=$?
  if [[ "$DRY_RUN" != 1 && -s "$TMP_LOG" ]]; then
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
      install -d -m 0755 /var/log/simha-aiops 2>/dev/null || true
      install -m 0600 "$TMP_LOG" "$FINAL_LOG" 2>/dev/null || true
    elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      sudo -n install -d -m 0755 /var/log/simha-aiops 2>/dev/null || true
      sudo -n install -m 0600 "$TMP_LOG" "$FINAL_LOG" 2>/dev/null || true
    fi
  fi
  rm -rf "$TMP_DIR"
  exit "$rc"
}
trap cleanup EXIT

exec > >(tee -a "$TMP_LOG") 2>&1

as_root(){
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required when not running as root."
    sudo "$@"
  fi
}

require_local_tools(){
  local cmd
  for cmd in bash curl install mktemp sha256sum awk grep sed tee head tr; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command missing: $cmd"
  done
}

require_ubuntu(){
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || \
    die "Ubuntu 24.04 LTS required; found ${PRETTY_NAME:-unknown}."
}

validate_inputs(){
  [[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "Invalid AIOPS_REPOSITORY."
  [[ "$REF" =~ ^[A-Za-z0-9._/-]+$ ]] || die "Invalid AIOPS_REF."
  [[ "$REF" != *".."* ]] || die "AIOPS_REF may not contain '..'."
  [[ "$REQUIRE_PIN" =~ ^[01]$ ]] || die "AIOPS_REQUIRE_PIN must be 0 or 1."
  [[ "$DRY_RUN" =~ ^[01]$ ]] || die "AIOPS_DRY_RUN must be 0 or 1."
  if [[ "$REQUIRE_PIN" == 1 && "$REF" == main ]]; then
    die "AIOPS_REQUIRE_PIN=1 requires AIOPS_REF to be a tag or commit, not main."
  fi
}

resolve_ref(){
  if [[ "$REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    RESOLVED_REF="${REF,,}"
    return 0
  fi

  local metadata="${TMP_DIR}/commit.json"
  say "Resolve: ${REPOSITORY}@${REF}"
  curl --fail --silent --show-error --location \
    --retry 4 --retry-all-errors --connect-timeout 10 --max-time 60 \
    --proto '=https' --tlsv1.2 \
    -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: simha-aiops-installer/1.0.1' \
    "https://api.github.com/repos/${REPOSITORY}/commits/${REF}" \
    -o "$metadata" || die "Unable to resolve repository reference '${REF}' to an immutable commit."

  RESOLVED_REF="$(
    grep -oE '"sha"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{40}"' "$metadata" \
      | head -n1 \
      | sed -E 's/.*"([0-9a-fA-F]{40})".*/\1/' \
      | tr '[:upper:]' '[:lower:]'
  )"
  [[ "$RESOLVED_REF" =~ ^[0-9a-f]{40}$ ]] || \
    die "GitHub returned no valid commit SHA for '${REF}'."
}

fetch(){
  local remote="$1" output="$2"
  say "Fetch: ${remote}"
  curl --fail --silent --show-error --location \
    --retry 4 --retry-all-errors --connect-timeout 10 --max-time 180 \
    --proto '=https' --tlsv1.2 \
    "https://raw.githubusercontent.com/${REPOSITORY}/${RESOLVED_REF}/${remote}" \
    -o "$output"
  [[ -s "$output" ]] || die "Downloaded file is empty: $remote"
}

expected_hash(){
  local rel="$1"
  awk -v f="$rel" '$2==f {print $1}' "$TMP_DIR/SHA256SUMS.txt" | head -n1
}

verify_download(){
  local rel="$1" file="$2" expected actual
  expected="$(expected_hash "$rel")"
  [[ -n "$expected" ]] || die "SHA256SUMS.txt has no entry for $rel"
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || \
    die "SHA-256 mismatch: $rel (expected $expected, got $actual)"
}

version_check(){
  local name="$1" file="$2"
  case "$name" in
    system-manager) grep -Fq 'readonly SYSTEM_MANAGER_VERSION="1.0.1"' "$file" ;;
    harness-manager) grep -Fq 'readonly HM_VERSION="1.0.1"' "$file" ;;
    hermes-manager) grep -Fq 'readonly HERMES_MANAGER_VERSION="1.0.1"' "$file" ;;
    nginx-manager) grep -Fq 'readonly NGM_VERSION="1.0.1"' "$file" ;;
    manager-suite) grep -Fq 'readonly SUITE_VERSION="1.0.1"' "$file" ;;
    *) grep -Eq '(^readonly )?MANAGER_VERSION="1\.0\.1"$' "$file" ;;
  esac || die "$name is not release version 1.0.1."
}

main(){
  require_local_tools
  if [[ "$DRY_RUN" != 1 ]]; then
    require_ubuntu
  fi
  validate_inputs
  resolve_ref

  say "SIMHA AiOps installer v${INSTALLER_VERSION}"
  say "Repository: ${REPOSITORY}"
  say "Requested:  ${REF}"
  say "Commit:     ${RESOLVED_REF}"
  say "Mode:       manager scripts only"
  if [[ "$DRY_RUN" == 1 ]]; then
    say "Dry run:    download/verification only"
  fi

  fetch "SHA256SUMS.txt" "$TMP_DIR/SHA256SUMS.txt"
  fetch "install-canonical-managers.sh" "$TMP_DIR/install-canonical-managers.sh"
  verify_download "install-canonical-managers.sh" "$TMP_DIR/install-canonical-managers.sh"
  chmod 0755 "$TMP_DIR/install-canonical-managers.sh"
  bash -n "$TMP_DIR/install-canonical-managers.sh"

  install -d -m 0755 "$TMP_DIR/scripts"
  local name
  for name in "${MANAGERS[@]}"; do
    fetch "scripts/${name}" "$TMP_DIR/scripts/${name}"
    verify_download "scripts/${name}" "$TMP_DIR/scripts/${name}"
    chmod 0755 "$TMP_DIR/scripts/${name}"
    bash -n "$TMP_DIR/scripts/${name}"
    "$TMP_DIR/scripts/${name}" help >/dev/null 2>&1 || die "Help smoke test failed: $name"
    version_check "$name" "$TMP_DIR/scripts/${name}"
  done

  (
    cd "$TMP_DIR"
    bash ./install-canonical-managers.sh --check
  )

  if [[ "$DRY_RUN" == 1 ]]; then
    say "DRY RUN PASS: immutable-ref downloads, checksums, syntax, help and version gates passed."
    return 0
  fi

  (
    cd "$TMP_DIR"
    as_root bash ./install-canonical-managers.sh all
  )

  say "Installed all 20 canonical manager commands."
  say "No managed runtime/service was installed, repaired, restarted or updated."
  say "Recommended next steps:"
  say "  manager-suite install-order"
  say "  manager-suite dependencies"
  say "  sudo system-manager install"
  say "Installer log: ${FINAL_LOG}"
}

main "$@"
