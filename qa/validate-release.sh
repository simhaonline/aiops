#!/usr/bin/env bash
readonly AIOPS_SCRIPT_VERSION="1.0.0"
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

cd "$(dirname "$0")/.."

readonly RELEASE_VERSION="1.0.0"
readonly EXPECTED_MANAGERS=23

die(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
pass(){ printf '[PASS] %s\n' "$*"; }

required_root=(
  README.md
  DEPENDENCIES.md
  INSTALLATION-ORDER.md
  SECURITY.md
  RELEASE-NOTES.md
  ADMIN-GUIDE.md
  USER-GUIDE.md
  PROJECT-ISOLATION.md
  MANIFEST.json
  SHA256SUMS.txt
  install.sh
  install-canonical-managers.sh
)

for f in "${required_root[@]}"; do
  [[ -f "$f" ]] || die "Required release file missing: $f"
done
pass "Required release files"

manager_count="$(find scripts -maxdepth 1 -type f | wc -l)"
[[ "$manager_count" -eq "$EXPECTED_MANAGERS" ]] || \
  die "Expected $EXPECTED_MANAGERS maintained manager scripts; found $manager_count."
pass "23 maintained suite scripts"

# Shell syntax: maintained managers, bootstrap and QA.
for f in install.sh install-canonical-managers.sh scripts/* qa/*.sh; do
  bash -n "$f" || die "bash -n failed: $f"
done
pass "Bash syntax for maintained managers, installers and QA"

# Manager help must be read-only and callable without a runtime installation.
for f in scripts/*; do
  "$f" help >/dev/null 2>&1 || die "help smoke test failed: $f"
done
pass "Manager help smoke tests"

# Every maintained manager has the unified suite version.
for name in scripts/*; do
  base="$(basename "$name")"
  case "$base" in
    system-manager) grep -Fq 'readonly SYSTEM_MANAGER_VERSION="1.0.0"' "$name" ;;
    harness-manager) grep -Fq 'readonly HM_VERSION="1.0.0"' "$name" ;;
    hermes-manager) grep -Fq 'readonly HERMES_MANAGER_VERSION="1.0.0"' "$name" ;;
    nginx-manager) grep -Fq 'readonly NGM_VERSION="1.0.0"' "$name" ;;
    manager-suite) grep -Fq 'readonly SUITE_VERSION="1.0.0"' "$name" ;;
    *) grep -Eq '(^readonly )?MANAGER_VERSION="1\.0\.0"$' "$name" ;;
  esac || die "$base is not manager release 1.0.0."
done
pass "Unified maintained-manager version 1.0.0"

grep -Fq 'readonly INSTALLER_VERSION="1.0.0"' install.sh || die "install.sh version mismatch."
grep -Fq 'readonly INSTALLER_VERSION="1.0.0"' install-canonical-managers.sh || die "canonical installer version mismatch."
for f in qa/*.sh; do
  grep -Fq 'readonly AIOPS_SCRIPT_VERSION="1.0.0"' "$f" || die "QA script version mismatch: $f"
done
pass "Release helper versions 1.0.0"

# Dependency and installation-order consistency.
grep -Fq 'REQUIRES nvm-manager AND ollama-manager' scripts/manager-suite || \
  die "manager-suite Harness dependency map is stale."
grep -Fq '**requires `nvm-manager` and `ollama-manager`**' README.md || \
  die "README Harness dependency map is stale."
scripts/manager-suite install-order >/tmp/aiops-order.$$ 2>/dev/null
scripts/manager-suite dependencies >/tmp/aiops-deps.$$ 2>/dev/null
python3 - /tmp/aiops-order.$$ /tmp/aiops-deps.$$ <<'PY'
from pathlib import Path
import re, sys
order = Path(sys.argv[1]).read_text()
deps = Path(sys.argv[2]).read_text()
names = [
"system-manager","docker-manager","forgejo-manager","forgejo-runner-manager","gvm-manager","miniconda-manager","nvm-manager",
"ollama-manager","nginx-manager","wireguard-manager","harness-manager","hermes-manager",
"codex-manager","claude-manager","opencode-manager","freebuff-manager","litellm-manager",
"llmrouter-manager","project-manager","collection-manager","aiops-dashboard-manager","manager-suite",
]
for n in names:
    if order.count(n) != 1:
        raise SystemExit(f"installation order must contain {n} exactly once")
    if n not in deps:
        raise SystemExit(f"dependency map missing {n}")
if order.index("nvm-manager") > order.index("harness-manager"):
    raise SystemExit("nvm-manager must precede harness-manager")
if order.index("ollama-manager") > order.index("harness-manager"):
    raise SystemExit("ollama-manager must precede harness-manager")
for n in ("opencode-manager","freebuff-manager","llmrouter-manager"):
    if order.index("nvm-manager") > order.index(n):
        raise SystemExit(f"nvm-manager must precede {n}")
PY
rm -f /tmp/aiops-order.$$ /tmp/aiops-deps.$$
pass "Dependency map and installation sequence"

# Key security policies that should never regress silently.
grep -Fq 'CONDA_CHANNELS="${CONDA_CHANNELS:-conda-forge}"' scripts/miniconda-manager || die "Miniconda conda-forge policy missing."
grep -Fq 'MINICONDA MANAGER SYSTEM BASH HOOK' scripts/miniconda-manager || die "Miniconda Bash activation hook missing."
grep -Fq 'Strict-Transport-Security "max-age=31536000" always' scripts/nginx-manager || die "Nginx HSTS policy missing."
grep -Fq 'ssl_protocols TLSv1.2 TLSv1.3;' scripts/nginx-manager || die "Nginx TLS policy missing."
grep -Fq 'proxy-add-api' scripts/nginx-manager || die "Nginx API-auth forwarding mode missing."
grep -Fq '127.0.0.1' scripts/harness-manager || die "Harness loopback host policy missing."
grep -Fq 'readonly HM_DEFAULT_HARNESS_PORT="3080"' scripts/harness-manager || die "Harness loopback port policy missing."
grep -Fq 'readonly HERMES_DASHBOARD_HOST="127.0.0.1"' scripts/hermes-manager || die "Hermes loopback host policy missing."
grep -Fq 'HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"' scripts/hermes-manager || die "Hermes loopback port policy missing."
grep -Fq '127.0.0.1:4000' scripts/litellm-manager || die "LiteLLM loopback policy missing."
grep -Fq '127.0.0.1:3000' scripts/llmrouter-manager || die "LMRouter loopback policy missing."
grep -Fq '127.0.0.1:4096' scripts/opencode-manager || die "OpenCode loopback policy missing."
grep -Fq 'nginx-setup DOMAIN EMAIL [AUTH_USER]' scripts/codex-manager || die "Codex authenticated WebSocket edge integration missing."
grep -Fq 'nginx-setup DOMAIN EMAIL' scripts/opencode-manager || die "OpenCode edge integration missing."
grep -Fq 'edge-add PATH NAME DOMAIN EMAIL [AUTH_USER]' scripts/project-manager || die "Project UI edge lifecycle missing."
grep -Fq 'assets.lock' scripts/project-manager || die "Project AI asset locking missing."
grep -Fq 'allow_mcp_inline_secrets: false' scripts/project-manager || die "Project MCP secret policy missing."
grep -Fq 'ghcr.io/d4vinci/scrapling@sha256:' scripts/collection-manager || die "Scrapling digest pin missing."
grep -Fq 'robots.txt disallows this collection URL' scripts/collection-manager || die "Collection robots policy missing."
grep -Fq 'schedule-add PROJECT NAME ONCALENDAR' scripts/collection-manager || die "Collection scheduling missing."
pass "Core security policy gates"

# Normal canonical source check validates the maintained managers.
bash install-canonical-managers.sh --check >/dev/null
pass "Canonical installer --check"

# Release checksums are authoritative for files fetched by install.sh and for
# the published repository inventory.
sha256sum -c SHA256SUMS.txt >/dev/null
pass "SHA256SUMS verification"

# Manifest metadata must agree with canonical files.
python3 - <<'PY'
from pathlib import Path
import hashlib, json

root=Path(".")
m=json.loads((root/"MANIFEST.json").read_text())
assert m["release"]=="1.0.0"
assert len(m["managers"])==23

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

for name, meta in m["managers"].items():
    p=root/"scripts"/name
    assert p.is_file(), name
    assert meta["version"]=="1.0.0", name
    assert meta["sha256"]==sha(p), name
    assert meta["size_bytes"]==p.stat().st_size, name

print("manifest integrity OK")
PY
pass "Manifest integrity"

qa/docker-manager-regression-test.sh >/dev/null
pass "Docker fresh-install regression"

qa/system-manager-regression-test.sh >/dev/null
pass "System-manager regression"

qa/account-group-collision-regression-test.sh >/dev/null
pass "Unix account/group collision regression"

qa/pipefail-safety-regression-test.sh >/dev/null
pass "Pipefail/SIGPIPE safety regression"

qa/harness-ollama-models-regression-test.sh >/dev/null
pass "Harness Ollama model-discovery regression"

qa/project-manager-regression-test.sh >/dev/null
pass "Project isolation backup/restore regression"

qa/collection-manager-regression-test.sh >/dev/null
pass "Scrapling collection policy/crawl/UI/backup/restore regression"

qa/dashboard-regression-test.sh >/dev/null
pass "Dashboard architecture/security/telemetry regression"

qa/forgejo-isolation-regression-test.sh >/dev/null
pass "Forgejo and runner trust-zone regression"

qa/aiops-regression-test.sh >/dev/null
pass "Unified AiOps runtime CLI regression"

qa/wireguard-manager-regression-test.sh >/dev/null
pass "WireGuard client storage regression"

qa/ollama-cloud-catalog-regression-test.sh >/dev/null
pass "Ollama Cloud-only model catalog regression"

qa/litellm-free-providers-regression-test.sh >/dev/null
pass "LiteLLM free-provider filtering regression"

qa/model-refresh-cron-regression-test.sh >/dev/null
pass "Scheduled model refresh regression"

# Test the real bootstrap download/check logic without Internet or mutation.
# The mock covers both GitHub commit resolution and raw downloads from the
# resulting immutable commit SHA.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' RETURN
mkdir -p "$tmp/bin"
cat >"$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
out=""
url=""
while (($#)); do
  case "$1" in
    -o|--output) out="${2:-}"; shift 2 ;;
    -H|--header) shift 2 ;;
    http://*|https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
[[ -n "$out" && -n "$url" ]] || { echo "mock curl: missing URL/output" >&2; exit 2; }

fake_sha="1111111111111111111111111111111111111111"
api="https://api.github.com/repos/simhaonline/aiops/commits/main"
raw="https://raw.githubusercontent.com/simhaonline/aiops/${fake_sha}/"

if [[ "$url" == "$api" ]]; then
  printf '{"sha":"%s"}\n' "$fake_sha" >"$out"
elif [[ "$url" == "$raw"* ]]; then
  rel="${url#"$raw"}"
  cp -- "${AIOPS_TEST_REPO_ROOT}/${rel}" "$out"
else
  echo "mock curl: unexpected URL $url" >&2
  exit 3
fi
MOCK
chmod 0755 "$tmp/bin/curl"

cat ./install.sh | env \
  PATH="$tmp/bin:$PATH" \
  AIOPS_TEST_REPO_ROOT="$PWD" \
  AIOPS_DRY_RUN=1 \
  bash >/dev/null

rm -rf "$tmp"
trap - RETURN
pass "One-line bootstrap immutable-ref dry-run"

# No sensitive/private material.
if grep -RIl --exclude='validate-release.sh' --exclude='SHA256SUMS.txt' --exclude-dir='.git' \
    -E -e '-----BEGIN (OPENSSH|RSA|EC|DSA|PRIVATE) PRIVATE KEY-----' . | grep -q .; then
  die "Private key material detected."
fi
pass "Private-key scan"

if grep -RIn --exclude='validate-release.sh' --exclude='SHA256SUMS.txt' --exclude-dir='.git' \
    -E '(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' . | grep -q .; then
  die "Credential-like token detected."
fi
pass "Credential-pattern scan"

# Plain-text build path scan.
if grep -RIn --exclude='validate-release.sh' --exclude='SHA256SUMS.txt' --exclude-dir='.git' \
    -E '/mnt/data/|/tmp/aiops-' \
    README.md DEPENDENCIES.md INSTALLATION-ORDER.md SECURITY.md RELEASE-NOTES.md \
    ADMIN-GUIDE.md USER-GUIDE.md PROJECT-ISOLATION.md \
    scripts qa install.sh install-canonical-managers.sh 2>/dev/null | grep -q .; then
  die "Build-machine path leaked into release text/scripts."
fi
pass "Build-path scan"

grep -Fq 'curl -fsSL https://raw.githubusercontent.com/simhaonline/aiops/main/install.sh | bash' README.md \
  || die "Required one-line installer is missing from README."
pass "README exact one-line installer"

echo
echo "SIMHA AIOPS RELEASE ${RELEASE_VERSION}: PASS"
