#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

readonly SYNC_VERSION="1.0.1"

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DST="${1:-}"

die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
info(){ printf '[INFO] %s\n' "$*"; }

[[ -n "$DST" ]] || die "Usage: $0 /path/to/checked-out-aiops-repo"
[[ -d "$DST/.git" ]] || die "Destination must be a checked-out Git repository: $DST"

cat <<EOF
This will replace the managed release areas in:
  $DST

Replaced:
  scripts/
  legacy/
  docs/
  qa/
  .github/workflows/validate.yml
  release root files

The .git directory and unrelated repository files are preserved.
EOF
read -r -p "Type SYNC-AIOPS-1.0.1 to continue: " answer
[[ "$answer" == "SYNC-AIOPS-1.0.1" ]] || die "Cancelled."

rm -rf "$DST/scripts" "$DST/legacy" "$DST/docs" "$DST/qa"
rm -rf "$DST/.github/workflows"
mkdir -p "$DST/.github/workflows"

cp -a "$SRC/scripts" "$DST/scripts"
cp -a "$SRC/legacy" "$DST/legacy"
cp -a "$SRC/docs" "$DST/docs"
cp -a "$SRC/qa" "$DST/qa"
cp -a "$SRC/.github/workflows/validate.yml" "$DST/.github/workflows/validate.yml"

for f in \
  README.md ABOUT.md DEPENDENCIES.md INSTALLATION-ORDER.md SECURITY.md RELEASE-NOTES.md \
  MANIFEST.json QA-REPORT.txt SHA256SUMS.txt .gitattributes .gitignore \
  install.sh install-canonical-managers.sh sync-github-repo.sh GITHUB-UPLOAD.md
do
  cp -a "$SRC/$f" "$DST/$f"
done

chmod 0755 "$DST/install.sh" "$DST/install-canonical-managers.sh" "$DST/sync-github-repo.sh"
chmod 0755 "$DST/scripts/"*
chmod 0755 "$DST/qa/"*.sh
chmod 0644 "$DST/legacy/"*.sh

(
  cd "$DST"
  bash qa/validate-release.sh
)

info "Repository synchronized to SIMHA AiOps 1.0.1."
info "Review with: cd '$DST' && git status && git diff --stat"
