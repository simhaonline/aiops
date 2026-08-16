#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.1"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

cd "$(dirname "$0")/.."

die(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
pass(){ printf '[PASS] %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || die "python3 is required."
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required."

# docs/ is a fully managed release directory. Remove stale historical
# generations before rebuilding MANIFEST.json and SHA256SUMS.txt.
bash qa/cleanup-docs.sh
pass "Canonical DOCX cleanup"

# Syntax/help gates first, while the old checksum manifest may be stale.
for f in install.sh install-canonical-managers.sh sync-github-repo.sh scripts/* legacy/*.sh qa/*.sh; do
  bash -n "$f" || die "bash -n failed: $f"
done
for f in scripts/*; do
  "$f" help >/dev/null 2>&1 || die "manager help failed: $f"
done
pass "Syntax/help preflight"

# Regenerate MANIFEST.json from the actual canonical bytes.
python3 - <<'PY'
from pathlib import Path
import hashlib, json, zipfile

root=Path(".")
release="1.0.1"

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def manager_version(name):
    return release

managers={}
for p in sorted((root/"scripts").iterdir()):
    if p.is_file():
        managers[p.name]={
            "version": manager_version(p.name),
            "sha256": sha(p),
            "size_bytes": p.stat().st_size,
        }

legacy={}
for p in sorted((root/"legacy").glob("*.sh")):
    legacy[p.name]={
        "release": release,
        "sha256": sha(p),
        "size_bytes": p.stat().st_size,
    }

documents=[]
for p in sorted((root/"docs").glob("*.docx")):
    with zipfile.ZipFile(p) as z:
        bad=z.testzip()
        if bad:
            raise SystemExit(f"Bad DOCX: {p}: {bad}")
    documents.append({
        "name": p.name,
        "sha256": sha(p),
        "size_bytes": p.stat().st_size,
    })

manifest={
    "release": release,
    "target_os": "Ubuntu 24.04 LTS",
    "managers": managers,
    "legacy_support": legacy,
    "documents": documents,
    "installer_policy": {
        "default_installs": "17 canonical manager scripts only",
        "legacy_default": False,
        "main_ref_resolution": "resolve to immutable Git commit before payload fetch",
    },
}
(root/"MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
pass "MANIFEST.json regenerated"

# SHA256SUMS must be generated LAST after all release content is final.
rm -f SHA256SUMS.txt
find . -type f \
  ! -path './.git/*' \
  ! -name 'SHA256SUMS.txt' \
  -print0 \
| sort -z \
| while IFS= read -r -d '' file; do
    sha256sum "${file#./}"
  done > SHA256SUMS.txt

sha256sum -c SHA256SUMS.txt >/dev/null
pass "SHA256SUMS.txt regenerated and verified"

bash qa/validate-release.sh
