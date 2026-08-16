#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

cd "$(dirname "$0")/.."

readonly CANONICAL_DOCS=(
  00-Master-Reference.docx
  01-system-manager-Reference.docx
  02-docker-manager-Reference.docx
  03-gvm-manager-Reference.docx
  04-miniconda-manager-Reference.docx
  05-nvm-manager-Reference.docx
  06-ollama-manager-Reference.docx
  07-nginx-manager-Reference.docx
  08-wireguard-manager-Reference.docx
  09-harness-manager-Reference.docx
  10-hermes-manager-Reference.docx
  11-codex-manager-Reference.docx
  12-claude-manager-Reference.docx
  13-opencode-manager-Reference.docx
  14-freebuff-manager-Reference.docx
  15-litellm-manager-Reference.docx
  16-llmrouter-manager-Reference.docx
  17-manager-suite-Reference.docx
  18-Migration-Guide.docx
)

die(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info(){ printf '[INFO] %s\n' "$*"; }

known_doc(){
  local candidate
  for candidate in "${CANONICAL_DOCS[@]}"; do
    [[ "$candidate" == "$1" ]] && return 0
  done
  return 1
}

[[ -d docs ]] || die "docs/ directory is missing."

removed=0
while IFS= read -r -d '' file; do
  base="$(basename "$file")"
  if ! known_doc "$base"; then
    info "Remove stale managed DOCX: docs/$base"
    rm -f -- "$file"
    ((removed+=1))
  fi
done < <(find docs -maxdepth 1 -type f -name '*.docx' -print0 | sort -z)

for base in "${CANONICAL_DOCS[@]}"; do
  [[ -f "docs/$base" ]] || die "Canonical DOCX missing: docs/$base"
done

count="$(find docs -maxdepth 1 -type f -name '*.docx' | wc -l)"
[[ "$count" -eq 19 ]] || die "Expected 19 canonical DOCX files after cleanup; found $count."

info "DOCX cleanup complete: removed=$removed retained=19"
